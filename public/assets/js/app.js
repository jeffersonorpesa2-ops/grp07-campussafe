/**
 * CampusSafe: Client-side Interactive Behaviors
 */

document.addEventListener('DOMContentLoaded', () => {
    // 1. Image and File Upload Preview
    const fileInput = document.getElementById('report_file_input');
    const previewContainer = document.getElementById('file_preview_container');
    const previewImg = document.getElementById('preview_image');
    const fileNameSpan = document.getElementById('preview_filename');

    if (fileInput && previewContainer) {
        fileInput.addEventListener('change', (e) => {
            const file = e.target.files[0];
            if (file) {
                previewContainer.style.display = 'block';
                if (fileNameSpan) {
                    fileNameSpan.textContent = `${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
                }

                if (file.type.startsWith('image/') && previewImg) {
                    const reader = new FileReader();
                    reader.onload = (loadEvent) => {
                        previewImg.src = loadEvent.target.result;
                        previewImg.style.display = 'block';
                    };
                    reader.readAsDataURL(file);
                } else if (previewImg) {
                    previewImg.style.display = 'none';
                }
            } else {
                previewContainer.style.display = 'none';
            }
        });
    }

    // 2. Demo Credential Fast-Fill on Login Page
    const demoButtons = document.querySelectorAll('.demo-login-btn');
    const usernameInput = document.getElementById('username');
    const passwordInput = document.getElementById('password');

    if (demoButtons.length > 0 && usernameInput && passwordInput) {
        demoButtons.forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                const user = btn.getAttribute('data-user');
                const pass = btn.getAttribute('data-pass');
                usernameInput.value = user;
                passwordInput.value = pass;
                usernameInput.focus();
            });
        });
    }

    // 3. Confirmation Dialogs for Destructive Actions
    const confirmButtons = document.querySelectorAll('[data-confirm]');
    confirmButtons.forEach(btn => {
        btn.addEventListener('click', (e) => {
            const msg = btn.getAttribute('data-confirm') || 'Are you sure you wish to proceed?';
            if (!confirm(msg)) {
                e.preventDefault();
            }
        });
    });

    // 4. Alert dismissal
    const alertCloseButtons = document.querySelectorAll('.btn-close');
    alertCloseButtons.forEach(btn => {
        btn.addEventListener('click', (e) => {
            const alertBox = btn.closest('.alert');
            if (alertBox) {
                alertBox.style.display = 'none';
            }
        });
    });
});
