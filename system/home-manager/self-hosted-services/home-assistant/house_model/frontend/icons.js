// Line icons, 24px grid, stroked with currentColor so each theme colours them.

const svg = (body) =>
  `<svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`;

export const ICONS = {
  light: svg('<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.8.8 1 1.5 1 2.5h6c0-1 .2-1.7 1-2.5A6 6 0 0 0 12 3z"/>'),
  climate: svg('<path d="M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9M9.5 4.5 12 6l2.5-1.5M9.5 19.5 12 18l2.5 1.5"/>'),
  camera: svg('<path d="M3 8h11v8H3zM14 10.5 20 8v8l-6-2.5"/>'),
  pump: svg('<path d="M12 3c3 4 5 6.5 5 9.5a5 5 0 0 1-10 0C7 9.5 9 7 12 3z"/>'),
  door: svg('<path d="M6 21V4h10v17M4 21h16M13 12h.01"/>'),
  motion: svg('<circle cx="12" cy="12" r="2"/><path d="M7.8 7.8a6 6 0 0 0 0 8.4M16.2 16.2a6 6 0 0 0 0-8.4"/>'),
  smoke: svg('<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2.5"/>'),
  leak: svg('<path d="M12 4c2.5 3.5 4 5.5 4 8a4 4 0 0 1-8 0c0-2.5 1.5-4.5 4-8zM4 20h16"/>'),
  car: svg('<path d="M5 16V12l2-5h10l2 5v4M3 16h18v2H3zM7.5 12h9"/>'),
  room: svg('<path d="M4 20V9l8-5 8 5v11zM10 20v-6h4v6"/>'),
  shield: svg('<path d="M12 3 5 6v5c0 4.5 3 8 7 10 4-2 7-5.5 7-10V6z"/>'),
  close: svg('<path d="M6 6l12 12M18 6 6 18"/>'),
  minus: svg('<path d="M5 12h14"/>'),
  plus: svg('<path d="M12 5v14M5 12h14"/>'),
};
