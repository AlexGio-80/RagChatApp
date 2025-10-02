using System;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

/// <summary>
/// SQL CLR functions for vector operations on VARBINARY embeddings
/// Compatible with SQL Server 2016+ (including 2025)
/// </summary>
public class SqlVectorFunctions
{
    /// <summary>
    /// Calculates cosine similarity between two VARBINARY embedding vectors
    /// </summary>
    /// <param name="embedding1">First embedding as VARBINARY (float32 array)</param>
    /// <param name="embedding2">Second embedding as VARBINARY (float32 array)</param>
    /// <returns>Cosine similarity score between -1.0 and 1.0 (higher is more similar)</returns>
    [SqlFunction(
        Name = "fn_CosineSimilarity",
        IsDeterministic = true,
        IsPrecise = false,
        DataAccess = DataAccessKind.None,
        SystemDataAccess = SystemDataAccessKind.None)]
    public static SqlDouble CosineSimilarity(SqlBytes embedding1, SqlBytes embedding2)
    {
        // Handle null inputs
        if (embedding1.IsNull || embedding2.IsNull)
            return SqlDouble.Null;

        byte[] bytes1 = embedding1.Value;
        byte[] bytes2 = embedding2.Value;

        // Validate lengths
        if (bytes1.Length == 0 || bytes2.Length == 0)
            return SqlDouble.Null;

        if (bytes1.Length != bytes2.Length)
            return SqlDouble.Null;

        // Ensure length is multiple of 4 (float32 = 4 bytes)
        if (bytes1.Length % 4 != 0)
            return SqlDouble.Null;

        int vectorLength = bytes1.Length / 4;

        // Calculate dot product, magnitude1, and magnitude2
        double dotProduct = 0.0;
        double magnitude1 = 0.0;
        double magnitude2 = 0.0;

        for (int i = 0; i < vectorLength; i++)
        {
            int byteOffset = i * 4;

            // Convert 4 bytes to float (little-endian)
            float value1 = BitConverter.ToSingle(bytes1, byteOffset);
            float value2 = BitConverter.ToSingle(bytes2, byteOffset);

            dotProduct += value1 * value2;
            magnitude1 += value1 * value1;
            magnitude2 += value2 * value2;
        }

        // Calculate magnitudes
        magnitude1 = Math.Sqrt(magnitude1);
        magnitude2 = Math.Sqrt(magnitude2);

        // Avoid division by zero
        if (magnitude1 == 0.0 || magnitude2 == 0.0)
            return 0.0;

        // Calculate cosine similarity
        double similarity = dotProduct / (magnitude1 * magnitude2);

        // Check for NaN or Infinity (can happen with extreme values)
        if (double.IsNaN(similarity) || double.IsInfinity(similarity))
            return 0.0;

        // Clamp to [-1, 1] range (handle floating point precision issues)
        if (similarity > 1.0) similarity = 1.0;
        if (similarity < -1.0) similarity = -1.0;

        return new SqlDouble(similarity);
    }

    /// <summary>
    /// Converts VARBINARY embedding to human-readable string (first N values)
    /// Useful for debugging
    /// </summary>
    [SqlFunction(
        Name = "fn_EmbeddingToString",
        IsDeterministic = true,
        IsPrecise = false,
        DataAccess = DataAccessKind.None)]
    public static SqlString EmbeddingToString(SqlBytes embedding, SqlInt32 maxValues)
    {
        if (embedding.IsNull)
            return SqlString.Null;

        byte[] bytes = embedding.Value;
        if (bytes.Length == 0 || bytes.Length % 4 != 0)
            return new SqlString("Invalid embedding");

        int vectorLength = bytes.Length / 4;
        int displayCount = maxValues.IsNull ? Math.Min(10, vectorLength) : Math.Min(maxValues.Value, vectorLength);

        string[] values = new string[displayCount];
        for (int i = 0; i < displayCount; i++)
        {
            float value = BitConverter.ToSingle(bytes, i * 4);
            values[i] = value.ToString("F6");
        }

        string result = $"[{string.Join(", ", values)}";
        if (displayCount < vectorLength)
            result += $", ... ({vectorLength} total)]";
        else
            result += "]";

        return new SqlString(result);
    }

    /// <summary>
    /// Gets the dimension (length) of an embedding vector
    /// </summary>
    [SqlFunction(
        Name = "fn_EmbeddingDimension",
        IsDeterministic = true,
        IsPrecise = true,
        DataAccess = DataAccessKind.None)]
    public static SqlInt32 EmbeddingDimension(SqlBytes embedding)
    {
        if (embedding.IsNull)
            return SqlInt32.Null;

        byte[] bytes = embedding.Value;
        if (bytes.Length == 0 || bytes.Length % 4 != 0)
            return SqlInt32.Null;

        return new SqlInt32(bytes.Length / 4);
    }

    /// <summary>
    /// Validates if a VARBINARY is a valid embedding
    /// </summary>
    [SqlFunction(
        Name = "fn_IsValidEmbedding",
        IsDeterministic = true,
        IsPrecise = true,
        DataAccess = DataAccessKind.None)]
    public static SqlBoolean IsValidEmbedding(SqlBytes embedding)
    {
        if (embedding.IsNull)
            return SqlBoolean.False;

        byte[] bytes = embedding.Value;

        // Must not be empty
        if (bytes.Length == 0)
            return SqlBoolean.False;

        // Must be multiple of 4 (float32)
        if (bytes.Length % 4 != 0)
            return SqlBoolean.False;

        // Check for NaN or Infinity values
        int vectorLength = bytes.Length / 4;
        for (int i = 0; i < vectorLength; i++)
        {
            float value = BitConverter.ToSingle(bytes, i * 4);
            if (float.IsNaN(value) || float.IsInfinity(value))
                return SqlBoolean.False;
        }

        return SqlBoolean.True;
    }

    /// <summary>
    /// Converts JSON array of floats to VARBINARY embedding using the same format as C# backend
    /// This ensures compatibility between SQL-generated and C#-generated embeddings
    /// </summary>
    /// <param name="jsonArray">JSON array string like "[0.1, 0.2, 0.3, ...]"</param>
    /// <returns>VARBINARY(MAX) in the same format as Buffer.BlockCopy</returns>
    [SqlFunction(
        Name = "fn_JsonArrayToEmbedding",
        IsDeterministic = true,
        IsPrecise = false,
        DataAccess = DataAccessKind.None)]
    public static SqlBytes JsonArrayToEmbedding(SqlString jsonArray)
    {
        if (jsonArray.IsNull)
            return SqlBytes.Null;

        try
        {
            string json = jsonArray.Value.Trim();

            // Remove brackets and whitespace
            if (json.StartsWith("["))
                json = json.Substring(1);
            if (json.EndsWith("]"))
                json = json.Substring(0, json.Length - 1);

            // Split by comma and parse floats
            string[] parts = json.Split(',');
            float[] floats = new float[parts.Length];

            for (int i = 0; i < parts.Length; i++)
            {
                string part = parts[i].Trim();
                if (!float.TryParse(part, System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture, out floats[i]))
                {
                    // Try with current culture as fallback
                    if (!float.TryParse(part, out floats[i]))
                        return SqlBytes.Null;
                }
            }

            // Convert to bytes using Buffer.BlockCopy (same as C# backend)
            byte[] bytes = new byte[floats.Length * 4];
            Buffer.BlockCopy(floats, 0, bytes, 0, bytes.Length);

            return new SqlBytes(bytes);
        }
        catch
        {
            return SqlBytes.Null;
        }
    }
}
