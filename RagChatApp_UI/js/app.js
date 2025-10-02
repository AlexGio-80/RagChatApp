// Configuration
const CONFIG = {
    API_BASE_URL: 'https://localhost:5001/api', // Adjust based on your server configuration
    MAX_FILE_SIZE: 50 * 1024 * 1024, // 50MB
    SUPPORTED_FILE_TYPES: ['.txt', '.pdf', '.doc', '.docx'],
    TOAST_DURATION: 5000
};

// Application State
const AppState = {
    currentTab: 'documents',
    documents: [],
    isLoading: false,
    chatMessages: [],
    pendingFiles: [], // Files waiting for metadata input
    isMetadataFormVisible: false
};

// DOM Elements
const elements = {
    tabButtons: document.querySelectorAll('.tab-btn'),
    tabContents: document.querySelectorAll('.tab-content'),
    dropZone: document.getElementById('dropZone'),
    fileInput: document.getElementById('fileInput'),
    textTitle: document.getElementById('textTitle'),
    textContent: document.getElementById('textContent'),
    indexTextBtn: document.getElementById('indexTextBtn'),
    refreshBtn: document.getElementById('refreshBtn'),
    documentsList: document.getElementById('documentsList'),
    documentsLoading: document.getElementById('documentsLoading'),
    chatMessages: document.getElementById('chatMessages'),
    messageInput: document.getElementById('messageInput'),
    sendBtn: document.getElementById('sendBtn'),
    maxChunks: document.getElementById('maxChunks'),
    maxChunksValue: document.getElementById('maxChunksValue'),
    similarityThreshold: document.getElementById('similarityThreshold'),
    similarityValue: document.getElementById('similarityValue'),
    statusText: document.getElementById('statusText'),
    modeIndicator: document.getElementById('modeIndicator'),
    toastContainer: document.getElementById('toastContainer'),
    // Metadata form elements
    metadataForm: document.getElementById('metadataForm'),
    documentNotes: document.getElementById('documentNotes'),
    detailAuthor: document.getElementById('detailAuthor'),
    detailType: document.getElementById('detailType'),
    detailLicense: document.getElementById('detailLicense'),
    detailLanguages: document.getElementById('detailLanguages'),
    detailServices: document.getElementById('detailServices'),
    detailTags: document.getElementById('detailTags'),
    customDetails: document.getElementById('customDetails'),
    uploadWithMetadata: document.getElementById('uploadWithMetadata'),
    skipMetadata: document.getElementById('skipMetadata'),
    cancelUpload: document.getElementById('cancelUpload'),
    // Text metadata elements
    textNotes: document.getElementById('textNotes'),
    textAuthor: document.getElementById('textAuthor'),
    textType: document.getElementById('textType'),
    textTags: document.getElementById('textTags'),
    textCustomDetails: document.getElementById('textCustomDetails')
};

// Initialize Application
document.addEventListener('DOMContentLoaded', function() {
    initializeEventListeners();
    loadDocuments();
    checkApiInfo();
    updateRangeValues();
});

// Event Listeners
function initializeEventListeners() {
    // Tab Navigation
    elements.tabButtons.forEach(button => {
        button.addEventListener('click', () => {
            const tab = button.getAttribute('data-tab');
            switchTab(tab);
        });
    });

    // File Upload
    elements.dropZone.addEventListener('click', () => elements.fileInput.click());
    elements.dropZone.addEventListener('dragover', handleDragOver);
    elements.dropZone.addEventListener('dragleave', handleDragLeave);
    elements.dropZone.addEventListener('drop', handleDrop);
    elements.fileInput.addEventListener('change', handleFileSelect);

    // Text Indexing
    elements.indexTextBtn.addEventListener('click', handleTextIndex);

    // Document Management
    elements.refreshBtn.addEventListener('click', loadDocuments);

    // Chat
    elements.sendBtn.addEventListener('click', sendMessage);
    elements.messageInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    // Settings
    elements.maxChunks.addEventListener('input', updateRangeValues);
    elements.similarityThreshold.addEventListener('input', updateRangeValues);

    // Metadata form events
    elements.uploadWithMetadata.addEventListener('click', handleUploadWithMetadata);
    elements.skipMetadata.addEventListener('click', handleSkipMetadata);
    elements.cancelUpload.addEventListener('click', handleCancelUpload);
}

// Tab Management
function switchTab(tabName) {
    // Update tab buttons
    elements.tabButtons.forEach(btn => {
        btn.classList.toggle('active', btn.getAttribute('data-tab') === tabName);
    });

    // Update tab content
    elements.tabContents.forEach(content => {
        content.classList.toggle('active', content.id === `${tabName}-tab`);
    });

    AppState.currentTab = tabName;
    updateStatus(`Switched to ${tabName} tab`);
}

// File Upload Handlers
function handleDragOver(e) {
    e.preventDefault();
    elements.dropZone.classList.add('drag-over');
}

function handleDragLeave(e) {
    e.preventDefault();
    elements.dropZone.classList.remove('drag-over');
}

function handleDrop(e) {
    e.preventDefault();
    elements.dropZone.classList.remove('drag-over');

    const files = Array.from(e.dataTransfer.files);
    processFiles(files);
}

function handleFileSelect(e) {
    const files = Array.from(e.target.files);
    processFiles(files);
}

function processFiles(files) {
    const validFiles = files.filter(file => validateFile(file));

    if (validFiles.length === 0) {
        elements.fileInput.value = '';
        return;
    }

    // Store files in pending state
    AppState.pendingFiles = validFiles;

    // Show metadata form
    showMetadataForm();

    // Reset file input after processing to allow re-selection of the same files
    elements.fileInput.value = '';
}

function validateFile(file) {
    // Check file size
    if (file.size > CONFIG.MAX_FILE_SIZE) {
        showToast(`File "${file.name}" is too large. Maximum size is 50MB.`, 'error');
        return false;
    }

    // Check file type
    const extension = '.' + file.name.split('.').pop().toLowerCase();
    if (!CONFIG.SUPPORTED_FILE_TYPES.includes(extension)) {
        showToast(`File type "${extension}" is not supported.`, 'error');
        return false;
    }

    return true;
}

async function uploadFile(file, metadata = null) {
    const formData = new FormData();
    formData.append('File', file);

    // Add metadata if provided
    if (metadata) {
        if (metadata.notes) {
            formData.append('Notes', metadata.notes);
        }
        if (metadata.details) {
            formData.append('Details', JSON.stringify(metadata.details));
        }
    }

    try {
        updateStatus(`Uploading ${file.name}...`);

        const response = await fetch(`${CONFIG.API_BASE_URL}/documents/upload`, {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result = await response.json();
        showToast(`File "${file.name}" uploaded successfully!`, 'success');
        loadDocuments(); // Refresh document list
        updateStatus('File uploaded successfully');

    } catch (error) {
        console.error('Upload error:', error);
        showToast(`Failed to upload "${file.name}": ${error.message}`, 'error');
        updateStatus('Upload failed');
    }
}

// Text Indexing
async function handleTextIndex() {
    const title = elements.textTitle.value.trim();
    const content = elements.textContent.value.trim();

    if (!title || !content) {
        showToast('Please provide both title and content.', 'warning');
        return;
    }

    try {
        elements.indexTextBtn.disabled = true;
        updateStatus('Indexing text...');

        // Collect metadata
        const metadata = collectTextMetadata();

        const payload = {
            title: title,
            content: content
        };

        // Add metadata if provided
        if (metadata.notes) {
            payload.notes = metadata.notes;
        }
        if (metadata.details && Object.keys(metadata.details).length > 0) {
            payload.details = JSON.stringify(metadata.details);
        }

        const response = await fetch(`${CONFIG.API_BASE_URL}/documents/index-text`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result = await response.json();
        showToast('Text indexed successfully with metadata!', 'success');

        // Clear form
        clearTextForm();

        loadDocuments(); // Refresh document list
        updateStatus('Text indexed successfully');

    } catch (error) {
        console.error('Index error:', error);
        showToast(`Failed to index text: ${error.message}`, 'error');
        updateStatus('Indexing failed');
    } finally {
        elements.indexTextBtn.disabled = false;
    }
}

// Document Management
async function loadDocuments() {
    try {
        elements.documentsLoading.style.display = 'block';
        updateStatus('Loading documents...');

        const response = await fetch(`${CONFIG.API_BASE_URL}/documents`);

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const documents = await response.json();
        AppState.documents = documents;
        renderDocuments(documents);
        updateStatus(`Loaded ${documents.length} documents`);

    } catch (error) {
        console.error('Load documents error:', error);
        showToast(`Failed to load documents: ${error.message}`, 'error');
        updateStatus('Failed to load documents');
        renderDocuments([]); // Show empty state
    } finally {
        elements.documentsLoading.style.display = 'none';
    }
}

function renderDocuments(documents) {
    if (documents.length === 0) {
        elements.documentsList.innerHTML = `
            <div class="loading">
                Nessun documento caricato. Carica il tuo primo documento per iniziare!
            </div>
        `;
        return;
    }

    const documentsHtml = documents.map(doc => `
        <div class="document-item">
            <div class="document-header">
                <div>
                    <div class="document-title">${escapeHtml(doc.fileName)}</div>
                    <div class="document-meta">
                        <div>Tipo: ${doc.contentType} • Dimensione: ${formatFileSize(doc.size)}</div>
                        <div>Caricato: ${formatDate(doc.uploadedAt)} • Chunk: ${doc.chunkCount}</div>
                        ${doc.processedAt ? `<div>Processato: ${formatDate(doc.processedAt)}</div>` : ''}
                    </div>
                </div>
                <div class="document-actions">
                    <span class="status-badge status-${doc.status.toLowerCase()}">${doc.status}</span>
                    <button class="btn btn-small btn-secondary" onclick="deleteDocument(${doc.id})">
                        🗑️ Elimina
                    </button>
                </div>
            </div>
        </div>
    `).join('');

    elements.documentsList.innerHTML = documentsHtml;
}

async function deleteDocument(documentId) {
    if (!confirm('Sei sicuro di voler eliminare questo documento?')) {
        return;
    }

    try {
        updateStatus('Deleting document...');

        const response = await fetch(`${CONFIG.API_BASE_URL}/documents/${documentId}`, {
            method: 'DELETE'
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        showToast('Document deleted successfully!', 'success');
        loadDocuments(); // Refresh document list
        updateStatus('Document deleted');

    } catch (error) {
        console.error('Delete error:', error);
        showToast(`Failed to delete document: ${error.message}`, 'error');
        updateStatus('Delete failed');
    }
}

// Chat Functionality
async function sendMessage() {
    const message = elements.messageInput.value.trim();

    if (!message) {
        showToast('Please enter a message.', 'warning');
        return;
    }

    // Add user message to chat
    addMessageToChat(message, 'user');
    elements.messageInput.value = '';
    elements.sendBtn.disabled = true;

    try {
        updateStatus('Generating AI response...');

        const chatRequest = {
            message: message,
            maxChunks: parseInt(elements.maxChunks.value),
            similarityThreshold: parseFloat(elements.similarityThreshold.value)
        };

        const response = await fetch(`${CONFIG.API_BASE_URL}/chat`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(chatRequest)
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result = await response.json();
        addMessageToChat(result.response, 'bot', result.sources, message);
        updateStatus('Response generated');

    } catch (error) {
        console.error('Chat error:', error);
        addMessageToChat(`Sorry, I encountered an error: ${error.message}`, 'bot');
        updateStatus('Chat error');
    } finally {
        elements.sendBtn.disabled = false;
        elements.messageInput.focus();
    }
}

function addMessageToChat(content, sender, sources = [], searchQuery = '') {
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${sender}-message`;

    let sourcesHtml = '';
    if (sources && sources.length > 0) {
        sourcesHtml = `
            <div class="message-sources">
                <strong>📚 Sources:</strong>
                ${sources.map((source, index) => {
                    const sourceContent = escapeHtml(source.content);
                    const highlightedContent = highlightSearchTerms(sourceContent, searchQuery);
                    const isLong = source.content.length > 300;

                    return `
                        <div class="source-item">
                            <div class="source-header">
                                <strong>${escapeHtml(source.documentName)}</strong>
                                ${source.headerContext ? `• ${escapeHtml(source.headerContext)}` : ''}
                                <span class="source-score">(Score: ${source.similarityScore.toFixed(2)})</span>
                                ${source.documentPath ? `
                                    <button class="btn-link" onclick="openDocument('${escapeHtml(source.documentPath).replace(/\\/g, '\\\\')}')" title="Apri documento">
                                        📂 Apri
                                    </button>
                                ` : ''}
                            </div>
                            <div class="source-content ${isLong ? 'collapsible' : ''}" data-source-index="${index}">
                                <div class="content-text">
                                    "${highlightedContent}"
                                </div>
                                ${isLong ? `
                                    <button class="expand-btn" onclick="toggleSourceContent(${index})" title="Espandi/Comprimi contenuto">
                                        <span class="expand-text">Mostra tutto</span>
                                        <span class="collapse-text" style="display: none;">Comprimi</span>
                                    </button>
                                ` : ''}
                            </div>
                        </div>
                    `;
                }).join('')}
            </div>
        `;
    }

    // Highlight search terms in main response as well
    const highlightedMainContent = sender === 'bot' && searchQuery
        ? highlightSearchTerms(escapeHtml(content), searchQuery)
        : escapeHtml(content);

    messageDiv.innerHTML = `
        <div class="message-content">
            <p>${highlightedMainContent.replace(/\n/g, '<br>')}</p>
            ${sourcesHtml}
        </div>
    `;

    elements.chatMessages.appendChild(messageDiv);
    elements.chatMessages.scrollTop = elements.chatMessages.scrollHeight;
}

// API Info
async function checkApiInfo() {
    try {
        const response = await fetch(`${CONFIG.API_BASE_URL}/info`);

        if (response.ok) {
            const info = await response.json();
            elements.modeIndicator.textContent = info.MockMode ? 'MOCK' : 'LIVE';
            elements.modeIndicator.className = `mode-indicator ${info.MockMode ? 'mock' : 'live'}`;
            updateStatus('Connected to API');
        } else {
            updateStatus('API connection failed');
        }
    } catch (error) {
        console.error('API info error:', error);
        updateStatus('API unavailable');
    }
}

// Utility Functions
function updateRangeValues() {
    elements.maxChunksValue.textContent = elements.maxChunks.value;
    elements.similarityValue.textContent = elements.similarityThreshold.value;
}

function updateStatus(message) {
    elements.statusText.textContent = message;
    console.log('Status:', message);
}

function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;

    elements.toastContainer.appendChild(toast);

    // Auto remove after duration
    setTimeout(() => {
        if (toast.parentNode) {
            toast.parentNode.removeChild(toast);
        }
    }, CONFIG.TOAST_DURATION);
}

function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString('it-IT', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function highlightSearchTerms(text, searchQuery) {
    if (!searchQuery || searchQuery.trim().length === 0) {
        return text;
    }

    // Extract words from search query (remove common words and punctuation)
    const searchTerms = searchQuery
        .toLowerCase()
        .split(/[^\w]+/)
        .filter(term => term.length > 2) // Only highlight words longer than 2 chars
        .filter(term => !['the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'were', 'be', 'been', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'should', 'could', 'can', 'may', 'might'].includes(term));

    let highlightedText = text;

    // Highlight each search term (case insensitive)
    searchTerms.forEach(term => {
        const regex = new RegExp(`(${term})`, 'gi');
        highlightedText = highlightedText.replace(regex, '<mark class="search-highlight">$1</mark>');
    });

    return highlightedText;
}

function toggleSourceContent(index) {
    const sourceContent = document.querySelector(`[data-source-index="${index}"]`);
    const expandText = sourceContent.querySelector('.expand-text');
    const collapseText = sourceContent.querySelector('.collapse-text');

    if (sourceContent.classList.contains('expanded')) {
        sourceContent.classList.remove('expanded');
        expandText.style.display = 'inline';
        collapseText.style.display = 'none';
    } else {
        sourceContent.classList.add('expanded');
        expandText.style.display = 'none';
        collapseText.style.display = 'inline';
    }
}

// Metadata Management Functions
function showMetadataForm() {
    AppState.isMetadataFormVisible = true;
    elements.metadataForm.style.display = 'block';
    elements.dropZone.style.display = 'none';
}

function hideMetadataForm() {
    AppState.isMetadataFormVisible = false;
    elements.metadataForm.style.display = 'none';
    elements.dropZone.style.display = 'block';
    clearMetadataForm();
}

function clearMetadataForm() {
    elements.documentNotes.value = '';
    elements.detailAuthor.value = '';
    elements.detailType.value = '';
    elements.detailLicense.value = '';
    elements.detailLanguages.value = '';
    elements.detailServices.value = '';
    elements.detailTags.value = '';
    elements.customDetails.value = '';
}

function clearTextForm() {
    elements.textTitle.value = '';
    elements.textContent.value = '';
    elements.textNotes.value = '';
    elements.textAuthor.value = '';
    elements.textType.value = '';
    elements.textTags.value = '';
    elements.textCustomDetails.value = '';
}

function collectFileMetadata() {
    const notes = elements.documentNotes.value.trim();
    const details = {};

    // Collect structured details
    if (elements.detailAuthor.value.trim()) {
        details.author = elements.detailAuthor.value.trim();
    }
    if (elements.detailType.value.trim()) {
        details.type = elements.detailType.value.trim();
    }
    if (elements.detailLicense.value.trim()) {
        details.license = elements.detailLicense.value.trim();
    }
    if (elements.detailLanguages.value.trim()) {
        details.languages = elements.detailLanguages.value.split(',').map(s => s.trim()).filter(s => s);
    }
    if (elements.detailServices.value.trim()) {
        details.services = elements.detailServices.value.split(',').map(s => s.trim()).filter(s => s);
    }
    if (elements.detailTags.value.trim()) {
        details.tags = elements.detailTags.value.split(',').map(s => s.trim()).filter(s => s);
    }

    // Merge with custom JSON if provided
    if (elements.customDetails.value.trim()) {
        try {
            const customJson = JSON.parse(elements.customDetails.value.trim());
            Object.assign(details, customJson);
        } catch (error) {
            showToast('Invalid JSON in custom details. Using structured details only.', 'warning');
        }
    }

    return { notes: notes || null, details: Object.keys(details).length > 0 ? details : null };
}

function collectTextMetadata() {
    const notes = elements.textNotes.value.trim();
    const details = {};

    // Collect structured details for text
    if (elements.textAuthor.value.trim()) {
        details.author = elements.textAuthor.value.trim();
    }
    if (elements.textType.value.trim()) {
        details.type = elements.textType.value.trim();
    }
    if (elements.textTags.value.trim()) {
        details.tags = elements.textTags.value.split(',').map(s => s.trim()).filter(s => s);
    }

    // Merge with custom JSON if provided
    if (elements.textCustomDetails.value.trim()) {
        try {
            const customJson = JSON.parse(elements.textCustomDetails.value.trim());
            Object.assign(details, customJson);
        } catch (error) {
            showToast('Invalid JSON in custom details. Using structured details only.', 'warning');
        }
    }

    return { notes: notes || null, details: Object.keys(details).length > 0 ? details : null };
}

// Metadata Form Event Handlers
async function handleUploadWithMetadata() {
    if (AppState.pendingFiles.length === 0) {
        showToast('No files selected for upload.', 'warning');
        return;
    }

    const metadata = collectFileMetadata();

    // Upload all pending files with metadata
    const uploadPromises = AppState.pendingFiles.map(file => uploadFile(file, metadata));

    try {
        elements.uploadWithMetadata.disabled = true;
        const fileCount = AppState.pendingFiles.length;
        await Promise.all(uploadPromises);
        hideMetadataForm();
        AppState.pendingFiles = [];
        showToast(`Successfully uploaded ${fileCount} file(s) with metadata!`, 'success');
    } catch (error) {
        showToast('Some files failed to upload. Check the console for details.', 'error');
    } finally {
        elements.uploadWithMetadata.disabled = false;
    }
}

async function handleSkipMetadata() {
    if (AppState.pendingFiles.length === 0) {
        showToast('No files selected for upload.', 'warning');
        return;
    }

    // Upload files without metadata
    const uploadPromises = AppState.pendingFiles.map(file => uploadFile(file));

    try {
        elements.skipMetadata.disabled = true;
        const fileCount = AppState.pendingFiles.length;
        await Promise.all(uploadPromises);
        hideMetadataForm();
        AppState.pendingFiles = [];
        showToast(`Successfully uploaded ${fileCount} file(s) without metadata!`, 'success');
    } catch (error) {
        showToast('Some files failed to upload. Check the console for details.', 'error');
    } finally {
        elements.skipMetadata.disabled = false;
    }
}

function handleCancelUpload() {
    AppState.pendingFiles = [];
    hideMetadataForm();
    showToast('File upload cancelled.', 'info');
}

// Global error handler
window.addEventListener('error', function(e) {
    console.error('Global error:', e.error);
    showToast('An unexpected error occurred. Please check the console for details.', 'error');
});

// Network error handler
window.addEventListener('unhandledrejection', function(e) {
    console.error('Unhandled promise rejection:', e.reason);
    if (e.reason.name === 'TypeError' && e.reason.message.includes('fetch')) {
        showToast('Network error: Unable to connect to the server. Please check if the API server is running.', 'error');
    }
});

// Document Opening Function
function openDocument(documentPath) {
    if (!documentPath) {
        showToast('Document path not available', 'warning');
        return;
    }

    // For Windows file paths, convert to file:// URL
    let fileUrl = documentPath;

    // Check if it's a Windows path (contains backslashes or starts with drive letter)
    if (documentPath.includes('\\') || /^[A-Za-z]:/.test(documentPath)) {
        // Convert Windows path to file:// URL
        fileUrl = 'file:///' + documentPath.replace(/\\/g, '/');
    }

    // Try to open the document
    try {
        // Attempt 1: Open in new window/tab
        const opened = window.open(fileUrl, '_blank');

        if (!opened || opened.closed || typeof opened.closed === 'undefined') {
            // Popup was blocked, show alternative
            showDocumentPathDialog(documentPath);
        } else {
            showToast('Opening document...', 'info');
        }
    } catch (error) {
        console.error('Error opening document:', error);
        showDocumentPathDialog(documentPath);
    }
}

// Show dialog with document path for manual opening
function showDocumentPathDialog(documentPath) {
    const message = `Il browser non può aprire direttamente i file locali. Percorso del documento:\n\n${documentPath}\n\nCopia il percorso e aprilo con il tuo file explorer.`;

    if (confirm(message + '\n\nVuoi copiare il percorso negli appunti?')) {
        copyToClipboard(documentPath);
    }
}

// Copy text to clipboard
function copyToClipboard(text) {
    // Modern API
    if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(() => {
            showToast('Percorso copiato negli appunti!', 'success');
        }).catch(err => {
            console.error('Failed to copy:', err);
            fallbackCopyToClipboard(text);
        });
    } else {
        fallbackCopyToClipboard(text);
    }
}

// Fallback clipboard copy for older browsers
function fallbackCopyToClipboard(text) {
    const textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.left = '-999999px';
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();

    try {
        const successful = document.execCommand('copy');
        if (successful) {
            showToast('Percorso copiato negli appunti!', 'success');
        } else {
            showToast('Impossibile copiare. Copia manualmente il percorso.', 'error');
        }
    } catch (err) {
        console.error('Fallback copy failed:', err);
        showToast('Impossibile copiare. Copia manualmente il percorso.', 'error');
    }

    document.body.removeChild(textArea);
}