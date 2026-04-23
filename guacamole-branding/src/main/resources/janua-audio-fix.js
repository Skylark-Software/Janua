/**
 * Janua Audio Context Fix
 *
 * Fixes the "AudioContext was prevented from starting automatically" error
 * by resuming the AudioContext after user interaction.
 *
 * This is required by modern browsers that block autoplay of audio until
 * the user has interacted with the page.
 */
(function() {
    'use strict';

    // Track if we've already set up the listeners
    var listenersAttached = false;
    var audioContextResumed = false;

    /**
     * Attempt to resume any suspended AudioContext instances
     */
    function resumeAudioContexts() {
        if (audioContextResumed) return;

        // Find all AudioContext instances and resume them
        // Guacamole creates AudioContext in Guacamole.RawAudioPlayer
        if (window.Guacamole && window.Guacamole.AudioContextFactory) {
            var ctx = window.Guacamole.AudioContextFactory.getAudioContext();
            if (ctx && ctx.state === 'suspended') {
                ctx.resume().then(function() {
                    console.log('[Janua] AudioContext resumed successfully');
                    audioContextResumed = true;
                }).catch(function(err) {
                    console.warn('[Janua] Failed to resume AudioContext:', err);
                });
            } else if (ctx) {
                audioContextResumed = true;
            }
        }

        // Also try to resume any global AudioContext that might exist
        if (window.AudioContext || window.webkitAudioContext) {
            // Check for suspended contexts in the page
            var audioElements = document.querySelectorAll('audio, video');
            audioElements.forEach(function(el) {
                if (el.paused) {
                    el.play().catch(function() {
                        // Ignore errors for elements that shouldn't play
                    });
                }
            });
        }
    }

    /**
     * Set up event listeners for user interaction
     */
    function setupListeners() {
        if (listenersAttached) return;
        listenersAttached = true;

        var events = ['click', 'keydown', 'touchstart', 'mousedown'];

        function onUserInteraction(e) {
            resumeAudioContexts();

            // Remove listeners after first successful interaction
            if (audioContextResumed) {
                events.forEach(function(event) {
                    document.removeEventListener(event, onUserInteraction, true);
                });
            }
        }

        events.forEach(function(event) {
            document.addEventListener(event, onUserInteraction, true);
        });

        console.log('[Janua] Audio context resume listeners attached');
    }

    // Set up listeners when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', setupListeners);
    } else {
        setupListeners();
    }

    // Also hook into Guacamole's audio system when it's available
    var originalAudioContextFactory = null;

    // Poll for Guacamole availability (it may load after this script)
    var checkInterval = setInterval(function() {
        if (window.Guacamole && window.Guacamole.AudioContextFactory) {
            clearInterval(checkInterval);

            // Wrap getAudioContext to auto-resume on interaction
            var originalGetAudioContext = window.Guacamole.AudioContextFactory.getAudioContext;
            window.Guacamole.AudioContextFactory.getAudioContext = function() {
                var ctx = originalGetAudioContext.apply(this, arguments);
                if (ctx && ctx.state === 'suspended' && !audioContextResumed) {
                    // Schedule resume on next user interaction
                    setupListeners();
                }
                return ctx;
            };

            console.log('[Janua] Hooked into Guacamole AudioContextFactory');
        }
    }, 100);

    // Stop checking after 30 seconds
    setTimeout(function() {
        clearInterval(checkInterval);
    }, 30000);

})();


/**
 * Janua Copyright / Trademark Footer
 *
 * Injects a fixed-position footer on every page (login screen and
 * authenticated views). Uses a MutationObserver so it survives
 * Angular's view swaps, which would otherwise tear it out.
 */
(function () {
    var FOOTER_ID = 'janua-copyright-footer';
    var FOOTER_TEXT =
        '© 2025–2026 Skylark Software LLC. ' +
        'Janua™ is a trademark of Skylark Software LLC.';

    function addFooter() {
        if (!document.body) return;
        if (document.getElementById(FOOTER_ID)) return;
        var f = document.createElement('div');
        f.id = FOOTER_ID;
        f.textContent = FOOTER_TEXT;
        f.style.cssText = [
            'position:fixed',
            'left:0',
            'right:0',
            'bottom:0',
            'padding:6px 12px',
            'font-size:11px',
            'line-height:1.4',
            'color:#aaa',
            'background:rgba(26,26,26,0.92)',
            'border-top:1px solid #4a4a4a',
            'text-align:center',
            'z-index:2147483647',
            'pointer-events:none',
            'font-family:system-ui,-apple-system,"Segoe UI",sans-serif',
            'white-space:nowrap',
            'overflow:hidden',
            'text-overflow:ellipsis'
        ].join(';') + ';';
        document.body.appendChild(f);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', addFooter);
    } else {
        addFooter();
    }

    // Angular rebuilds DOM on view transitions; reattach when the footer
    // disappears.
    if (window.MutationObserver) {
        var obs = new MutationObserver(function () {
            if (!document.getElementById(FOOTER_ID)) addFooter();
        });
        obs.observe(document.documentElement, { childList: true, subtree: true });
    }
})();


/**
 * Janua About Menu + Modal
 *
 * Injects an "About Janua" item into the user dropdown menu (above
 * Logout) and shows a modal with version, license, third-party
 * notices, and trademark information when clicked.
 */
(function () {
    var MENU_ITEM_ID = 'janua-about-menu-item';
    var MODAL_ID = 'janua-about-modal';

    var VERSION = '1.0.0';
    var BUILD = '__BUILD__';
    var BUILT_ON = 'Apache Guacamole 1.6.0 + FreeRDP 3.10.3, with RDPSND v8 and H.264/AVC for RDPGFX';

    function buildModal() {
        var overlay = document.createElement('div');
        overlay.id = MODAL_ID;
        overlay.setAttribute('role', 'dialog');
        overlay.setAttribute('aria-modal', 'true');
        overlay.style.cssText = [
            'position:fixed',
            'top:0', 'left:0', 'right:0', 'bottom:0',
            'background:rgba(0,0,0,0.75)',
            'z-index:2147483646',
            'display:flex',
            'align-items:center',
            'justify-content:center',
            'padding:20px',
            'font-family:system-ui,-apple-system,"Segoe UI",sans-serif'
        ].join(';') + ';';

        var panel = document.createElement('div');
        panel.style.cssText = [
            'background:#2a2a2a',
            'color:#f5f0e8',
            'border:1px solid #4a4a4a',
            'border-radius:6px',
            'padding:28px 32px',
            'max-width:640px',
            'width:100%',
            'max-height:85vh',
            'overflow-y:auto',
            'line-height:1.55',
            'font-size:14px',
            'box-shadow:0 10px 40px rgba(0,0,0,0.5)'
        ].join(';') + ';';

        panel.innerHTML = [
            '<div style="text-align:center;margin:0 0 1em">',
            '<img src="app/ext/janua-branding/images/janua-logo.png" alt="Janua" style="max-width:165px;height:auto" />',
            '</div>',
            '<h2 style="margin:0 0 0.25em;padding:0;font-size:1.55em;color:#f5f0e8 !important;text-align:left;text-transform:none">About Janua™</h2>',
            '<hr style="border:0;border-top:1px solid #4a4a4a;margin:0.5em 0 1em">',
            '<p style="margin:0.25em 0"><strong>Version:</strong> ' + VERSION + (BUILD && BUILD.indexOf('__') !== 0 ? ' (build ' + BUILD + ')' : '') + '</p>',
            '<p style="margin:0.25em 0"><strong>Built on:</strong> ' + BUILT_ON + '</p>',
            '<hr style="border:0;border-top:1px solid #4a4a4a;margin:1em 0">',
            '<p style="margin:0.25em 0"><strong>Copyright © 2025–2026 Skylark Software LLC.</strong> All rights reserved.</p>',
            '<p style="margin:0.25em 0">Janua™ is a trademark of Skylark Software LLC.</p>',
            '<h3 style="margin:1.25em 0 0.5em;font-size:1.05em;color:#f5f0e8">License</h3>',
            '<p style="margin:0.25em 0">Janua is licensed under <a style="color:#6a9fb5;text-decoration:none" href="https://github.com/Skylark-Software/Janua/blob/main/LICENSE" target="_blank" rel="noopener">GPL-3.0-only</a>.</p>',
            '<h3 style="margin:1.25em 0 0.5em;font-size:1.05em;color:#f5f0e8">Third-Party Components</h3>',
            '<ul style="margin:0.25em 0;padding-left:1.4em">',
            '<li style="margin-bottom:0.5em"><strong>Apache Guacamole</strong> — Apache License 2.0.<br>Copyright © The Apache Software Foundation.<br>Apache Guacamole and the Apache feather logo are trademarks of The Apache Software Foundation. Janua is not affiliated with or endorsed by the Apache Software Foundation.</li>',
            '<li style="margin-bottom:0.5em"><strong>FreeRDP</strong> — Apache License 2.0.<br>Copyright © The FreeRDP Project.</li>',
            '<li style="margin-bottom:0.5em"><strong>PostgreSQL</strong> — PostgreSQL License.<br>Copyright © The PostgreSQL Global Development Group.</li>',
            '</ul>',
            '<h3 style="margin:1.25em 0 0.5em;font-size:1.05em;color:#f5f0e8">Links</h3>',
            '<ul style="margin:0.25em 0;padding-left:1.4em">',
            '<li><a style="color:#6a9fb5;text-decoration:none" href="https://janua.me" target="_blank" rel="noopener">janua.me</a></li>',
            '<li><a style="color:#6a9fb5;text-decoration:none" href="https://skylarksoftware.me" target="_blank" rel="noopener">Skylark Software</a></li>',
            '<li><a style="color:#6a9fb5;text-decoration:none" href="https://github.com/Skylark-Software/Janua" target="_blank" rel="noopener">GitHub repository</a></li>',
            '</ul>',
            '<hr style="border:0;border-top:1px solid #4a4a4a;margin:1em 0 1em">',
            '<div style="text-align:center;margin:0 0 0.5em">',
            '<a href="https://skylarksoftware.me" target="_blank" rel="noopener" style="display:inline-block">',
            '<img src="app/ext/janua-branding/images/skylark-software-logo.svg" alt="Skylark Software" style="width:100%;max-width:336px;height:auto" />',
            '</a>',
            '</div>',
            '<div style="text-align:right;margin-top:1em">',
            '<button id="janua-about-close" style="background:#3a3a3a;color:#f5f0e8;border:1px solid #5a5a5a;padding:0.5em 1.5em;border-radius:4px;cursor:pointer;font-size:14px;font-family:inherit">Close</button>',
            '</div>'
        ].join('');

        overlay.appendChild(panel);

        function dismiss() { if (overlay.parentNode) overlay.parentNode.removeChild(overlay); }
        overlay.addEventListener('click', function (e) { if (e.target === overlay) dismiss(); });
        panel.querySelector('#janua-about-close').addEventListener('click', dismiss);
        document.addEventListener('keydown', function onKey(e) {
            if (e.key === 'Escape') { dismiss(); document.removeEventListener('keydown', onKey); }
        });

        return overlay;
    }

    function showAboutModal() {
        if (document.getElementById(MODAL_ID)) return;
        document.body.appendChild(buildModal());
    }

    function addAboutMenuItem() {
        if (document.getElementById(MENU_ITEM_ID)) return;
        var logoutLink = document.querySelector('.user-menu .menu-dropdown .menu-contents li a.logout');
        if (!logoutLink) return;
        var logoutLi = logoutLink.closest('li');
        if (!logoutLi || !logoutLi.parentNode) return;

        var li = document.createElement('li');
        li.id = MENU_ITEM_ID;
        var a = document.createElement('a');
        a.href = '#';
        a.className = 'about';
        // Wrap text in a span with explicit color/fill overrides — some
        // Guacamole themes clamp anchor color with -webkit-text-fill-color,
        // which `color` alone can't override.
        var span = document.createElement('span');
        span.textContent = 'About Janua';
        span.style.setProperty('color', '#f5f0e8', 'important');
        span.style.setProperty('-webkit-text-fill-color', '#f5f0e8', 'important');
        a.appendChild(span);
        // Match Guacamole's menu-item padding and icon layout; use the
        // branded favicon as the About glyph.
        a.style.cssText = [
            'background-repeat:no-repeat',
            'background-size:1em',
            'background-position:.75em',
            'padding-left:2.5em',
            'background-image:url(app/ext/janua-branding/images/janua-icon.svg)'
        ].join(';') + ';';
        a.style.setProperty('color', '#f5f0e8', 'important');
        a.style.setProperty('-webkit-text-fill-color', '#f5f0e8', 'important');
        a.addEventListener('click', function (e) {
            e.preventDefault();
            showAboutModal();
        });
        li.appendChild(a);
        // Place About as the last menu item (after Logout).
        logoutLi.parentNode.appendChild(li);
    }

    function tryAdd() { addAboutMenuItem(); }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', tryAdd);
    } else {
        tryAdd();
    }

    // The user menu mounts and re-mounts as the Angular app transitions;
    // reattach whenever our item disappears.
    if (window.MutationObserver) {
        var obs = new MutationObserver(function () {
            if (!document.getElementById(MENU_ITEM_ID)) tryAdd();
        });
        obs.observe(document.documentElement, { childList: true, subtree: true });
    }
})();
