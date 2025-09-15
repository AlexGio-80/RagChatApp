// Configuration
const CONFIG = {
    API_BASE_URL: 'https://localhost:7297/api', // Adjust based on your server configuration
    MAX_FILE_SIZE: 50 * 1024 * 1024, // 50MB
    SUPPORTED_FILE_TYPES: ['.txt', '.pdf', '.doc', '.docx'],
    TOAST_DURATION: 5000
};

// Application State
const AppState = {
    currentTab: 'documents',
    documents: [],
    isLoading: false,
    chatMessages: []
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
    toastContainer: document.getElementById('toastContainer')
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
    files.forEach(file => {
        if (validateFile(file)) {
            uploadFile(file);
        }
    });
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

async function uploadFile(file) {
    const formData = new FormData();
    formData.append('File', file);

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

        const response = await fetch(`${CONFIG.API_BASE_URL}/documents/index-text`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                title: title,
                content: content
            })
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result = await response.json();
        showToast('Text indexed successfully!', 'success');

        // Clear form
        elements.textTitle.value = '';
        elements.textContent.value = '';

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
        addMessageToChat(result.response, 'bot', result.sources);
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

function addMessageToChat(content, sender, sources = []) {
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${sender}-message`;

    let sourcesHtml = '';
    if (sources && sources.length > 0) {
        sourcesHtml = `
            <div class="message-sources">
                <strong>📚 Sources:</strong>
                ${sources.map(source => `
                    <div class="source-item">
                        <div class="source-header">
                            ${escapeHtml(source.documentName)}
                            ${source.headerContext ? `• ${escapeHtml(source.headerContext)}` : ''}
                            (Score: ${source.similarityScore.toFixed(2)})
                        </div>
                        <div class="source-content">
                            "${escapeHtml(source.content.substring(0, 200))}${source.content.length > 200 ? '...' : ''}"
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
    }

    messageDiv.innerHTML = `
        <div class="message-content">
            <p>${escapeHtml(content).replace(/\n/g, '<br>')}</p>
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