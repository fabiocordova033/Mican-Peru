/** Logo Mican: huella en cuadro redondeado + palabra "mican". */
export function Logo() {
  return (
    <div className="logo">
      <svg width="48" height="48" viewBox="0 0 48 48" aria-hidden="true">
        <rect width="48" height="48" rx="12" fill="var(--primario)" />
        <g fill="var(--acento)">
          <ellipse cx="15" cy="20" rx="3.2" ry="4" />
          <ellipse cx="21" cy="14" rx="3.2" ry="4" />
          <ellipse cx="27" cy="14" rx="3.2" ry="4" />
          <ellipse cx="33" cy="20" rx="3.2" ry="4" />
        </g>
        <path
          fill="#fff"
          d="M24 22c-5 0-9.5 6-9.5 9.8 0 2.6 2.1 3.9 4.6 3.9 2 0 3.2-1 4.9-1s2.9 1 4.9 1c2.5 0 4.6-1.3 4.6-3.9C33.5 28 29 22 24 22Z"
        />
      </svg>
      <span className="logo-texto">mican</span>
    </div>
  );
}
