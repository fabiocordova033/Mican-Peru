/// <reference types="vitest/config" />
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  // La fuente Nunito se comparte con la app móvil (../app/assets/fuentes).
  server: { port: 5173, fs: { allow: [".."] } },
  build: { chunkSizeWarningLimit: 1000 },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./test/setup.ts"],
    css: false,
  },
});
