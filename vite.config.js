import { defineConfig } from 'vite'
import { fileURLToPath } from 'node:url'

// Preview live de la maquette web/ de mBAE (rechargement à chaque sauvegarde)
export default defineConfig({
  root: 'web',
  // i18n/ est lu par web/i18n.js (même table de traductions que l'appli) : hors de la racine Vite, donc à autoriser.
  server: { port: Number(process.env.PORT) || 5174, strictPort: true, fs: { allow: [fileURLToPath(new URL('.', import.meta.url))] } },
})
