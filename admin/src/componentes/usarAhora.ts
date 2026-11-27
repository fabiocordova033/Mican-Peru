import { useEffect, useState } from "react";

/** La hora actual, refrescada cada minuto (para los contadores de horas). */
export function useAhora(cadaMs = 60_000): Date {
  const [ahora, setAhora] = useState(() => new Date());
  useEffect(() => {
    const id = setInterval(() => setAhora(new Date()), cadaMs);
    return () => clearInterval(id);
  }, [cadaMs]);
  return ahora;
}
