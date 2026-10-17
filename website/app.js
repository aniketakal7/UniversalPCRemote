/**
 * Universal PC Remote — Production Interactive Script
 * Modular client-side interaction engine.
 */

(function () {
  'use strict';

  // DOM Helpers
  const $ = (selector, parent = document) => parent.querySelector(selector);
  const $$ = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

  // 1. Dynamic Year
  const yearEl = $('#year');
  if (yearEl) {
    yearEl.textContent = String(new Date().getFullYear());
  }

  // 2. Toast Notification System
  let toastTimer = null;
  const toastEl = $('#toast');

  function toast(message) {
    if (!toastEl) return;
    toastEl.textContent = message;
    toastEl.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => {
      toastEl.classList.remove('show');
    }, 2500);
  }

  // 3. Mobile Navigation Drawer (Zero Click-Blocking)
  const menuBtn = $('#menuBtn');
  const navLinks = $('#navLinks');

  function setMenu(open) {
    if (!navLinks || !menuBtn) return;
    navLinks.classList.toggle('open', open);
    menuBtn.setAttribute('aria-expanded', String(open));
    menuBtn.setAttribute('aria-label', open ? 'Close navigation menu' : 'Open navigation menu');
    menuBtn.textContent = open ? '✕' : '☰';
    document.body.classList.toggle('menu-open', open && window.innerWidth <= 1024);
  }

  if (menuBtn) {
    menuBtn.addEventListener('click', () => {
      const isOpen = menuBtn.getAttribute('aria-expanded') === 'true';
      setMenu(!isOpen);
    });
  }

  $$('#navLinks a').forEach((link) => {
    link.addEventListener('click', () => setMenu(false));
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') setMenu(false);
  });

  window.addEventListener('resize', () => {
    if (window.innerWidth > 1024) {
      setMenu(false);
    }
  });

  // 4. Interactive Touchpad Simulation Engine
  const pad = $('#demoPad');
  const cursor = $('#demoCursor');

  function attachPad(padElement, cursorElement) {
    if (!padElement || !cursorElement) return;

    const move = (e) => {
      const rect = padElement.getBoundingClientRect();
      if (!rect.width || !rect.height) return;
      const x = Math.max(4, Math.min(96, ((e.clientX - rect.left) / rect.width) * 100));
      const y = Math.max(6, Math.min(94, ((e.clientY - rect.top) / rect.height) * 100));
      cursorElement.style.left = `${x}%`;
      cursorElement.style.top = `${y}%`;
    };

    padElement.addEventListener('pointermove', move);
    padElement.addEventListener('pointerdown', (e) => {
      move(e);
      toast('Touchpad coordinate sent (8ms)');
    });
  }

  attachPad(pad, cursor);

  // 5. Interactive Demo Mode Controller
  const modes = {
    pointer: {
      label: 'POINTER & TRACKPAD MODE',
      title: 'A little movement.<br>A lot of freedom.',
      desc: 'Move your pointer over the touchpad or swipe on mobile. Supports click-to-tap and drag-lock.',
      cursor: '⌖',
      actionTitle: 'Your Mouse Controls',
      actionDesc: 'Select an action to test micro-latency response.',
      actions: ['Left click', 'Right click', 'Double click', 'Middle click']
    },
    keyboard: {
      label: 'KEYBOARD & SHORTCUTS MODE',
      title: 'Full keys from<br>where you sit.',
      desc: 'Type and trigger Windows global shortcuts directly from your phone deck.',
      cursor: '⌨',
      actionTitle: 'Windows System Hotkeys',
      actionDesc: 'Simulate high-value Windows shortcut combinations.',
      actions: ['Esc', 'Alt+Tab', 'Win+E', 'Ctrl+Z', 'Ctrl+C', 'Ctrl+V']
    },
    media: {
      label: 'MEDIA TRANSPORT DECK',
      title: 'Keep playback<br>within arm’s reach.',
      desc: 'Manage playback, skip tracks, and adjust master workstation volume without reaching for the keyboard.',
      cursor: '♫',
      actionTitle: 'Media Transport',
      actionDesc: 'Trigger audio and transport actions.',
      actions: ['Play / pause', 'Volume up (+5%)', 'Volume down (-5%)', 'Mute audio', 'Next track']
    },
    present: {
      label: 'PRESENTATION SLIDE CLICKER',
      title: 'Own the room.<br>Next slide at hand.',
      desc: 'Step through Keynote, PowerPoint, or Google Slides with clear haptic taps and slide feedback.',
      cursor: '▣',
      actionTitle: 'Slide Controls',
      actionDesc: 'Simulate presentation navigation.',
      actions: ['Next slide ➔', 'Previous slide ⬅', 'Start presentation (F5)', 'Black screen (B)']
    },
    power: {
      label: 'WORKSTATION POWER CONTROLS',
      title: 'Instant power.<br>Zero walking.',
      desc: 'Put displays to sleep, lock your workstation, or trigger low-power stand-by with two taps.',
      cursor: '⚡',
      actionTitle: 'System Power Deck',
      actionDesc: 'Simulate secure Windows power commands.',
      actions: ['Lock workstation (Win+L)', 'Turn off monitors', 'Sleep workstation', 'Cancel / Esc']
    }
  };

  let currentMode = 'pointer';
  let slideNumber = 1;
  let isMediaPlaying = false;

  function perform(action) {
    let message = `Executed: ${action}`;

    if (currentMode === 'media' && action === 'Play / pause') {
      isMediaPlaying = !isMediaPlaying;
      message = isMediaPlaying ? 'Playback started · Sending VK_MEDIA_PLAY' : 'Playback paused · Sending VK_MEDIA_PAUSE';
      const actionTitle = $('#actionTitle');
      if (actionTitle) actionTitle.textContent = isMediaPlaying ? 'Now Playing.' : 'Paused.';
    }

    if (currentMode === 'present') {
      if (action.includes('Next')) slideNumber++;
      if (action.includes('Previous')) slideNumber = Math.max(1, slideNumber - 1);
      if (action.includes('slide')) {
        message = `Presentation Deck · Slide ${slideNumber}`;
        const actionTitle = $('#actionTitle');
        if (actionTitle) actionTitle.textContent = `Slide ${slideNumber} Active.`;
      }
      if (action.includes('Start')) message = 'F5 triggered · Slideshow started in full screen.';
      if (action.includes('Black')) message = 'B key triggered · Screen blanked.';
    }

    if (currentMode === 'keyboard') {
      message = `Shortcut dispatched: ${action} via Local Wi-Fi (8ms)`;
    }

    if (currentMode === 'power') {
      message = `Power signal dispatched: ${action}`;
    }

    const feedback = $('#feedback');
    if (feedback) feedback.textContent = message;
    toast(message);
  }

  function renderMode(nextMode) {
    currentMode = nextMode;
    const data = modes[nextMode];
    if (!data) return;

    $$('.mode').forEach((btn) => {
      btn.setAttribute('aria-pressed', String(btn.dataset.mode === nextMode));
    });

    const modeLabel = $('#modeLabel');
    const demoTitle = $('#demoTitle');
    const demoDesc = $('#demoDescription');
    const demoCursor = $('#demoCursor');
    const actionTitle = $('#actionTitle');
    const actionDesc = $('#actionDescription');
    const feedback = $('#feedback');
    const holder = $('#actionButtons');

    if (modeLabel) modeLabel.textContent = data.label;
    if (demoTitle) demoTitle.innerHTML = data.title;
    if (demoDesc) demoDesc.textContent = data.desc;
    if (demoCursor) demoCursor.textContent = data.cursor;
    if (actionTitle) actionTitle.textContent = data.actionTitle;
    if (actionDesc) actionDesc.textContent = data.actionDesc;

    if (feedback) {
      if (nextMode === 'present') feedback.textContent = `Slide ${slideNumber} · Ready`;
      else if (nextMode === 'media') feedback.textContent = `Playback ${isMediaPlaying ? 'playing' : 'paused'} · Ready`;
      else feedback.textContent = 'Ready when you are (8ms latency).';
    }

    if (holder) {
      holder.replaceChildren();
      data.actions.forEach((label) => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'action';
        btn.textContent = label;
        btn.dataset.action = label;
        btn.addEventListener('click', () => perform(label));
        holder.appendChild(btn);
      });
    }
  }

  $$('.mode').forEach((btn) => {
    btn.addEventListener('click', () => renderMode(btn.dataset.mode));
  });

  // Attach click listener for initial action buttons
  $$('#actionButtons .action').forEach((btn) => {
    btn.addEventListener('click', () => perform(btn.dataset.action));
  });

  // 6. Accessible FAQ Accordion Engine
  $$('.faq-question').forEach((button) => {
    button.addEventListener('click', () => {
      const item = button.closest('.faq-item');
      if (!item) return;
      const wasOpen = item.classList.contains('open');
      
      // Optional single-open behavior:
      $$('.faq-item').forEach((otherItem) => {
        if (otherItem !== item) {
          otherItem.classList.remove('open');
          const otherBtn = otherItem.querySelector('.faq-question');
          if (otherBtn) otherBtn.setAttribute('aria-expanded', 'false');
        }
      });

      const isOpen = !wasOpen;
      item.classList.toggle('open', isOpen);
      button.setAttribute('aria-expanded', String(isOpen));
    });
  });

  // 7. Scroll Reveal Animation (Intersection Observer)
  const reveals = $$('.reveal');
  if ('IntersectionObserver' in window && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.08 }
    );
    reveals.forEach((el) => observer.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add('visible'));
  }

  // 8. OS & Architecture Detection Badge
  const isWindows = navigator.userAgent.indexOf('Win') !== -1;
  const isAndroid = navigator.userAgent.indexOf('Android') !== -1;
  const detectionBadge = $('#detectionBadge');
  if (detectionBadge) {
    if (isWindows) {
      detectionBadge.textContent = 'Windows PC Detected — Ready to run Companion';
    } else if (isAndroid) {
      detectionBadge.textContent = 'Android Device Detected — Ready to install APK';
    }
  }

})();
