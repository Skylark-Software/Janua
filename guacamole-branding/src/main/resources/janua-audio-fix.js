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
