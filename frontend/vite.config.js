import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import tailwindcss from "@tailwindcss/vite";
import { VitePWA } from "vite-plugin-pwa";
import { fileURLToPath, URL } from "node:url";

export default defineConfig({
  plugins: [
    tailwindcss(),
    vue(),
    VitePWA({
      registerType: "autoUpdate",
      workbox: {
        skipWaiting: true,
        clientsClaim: true,
        // Makes client-side routes (Vue Router) work when offline / on refresh
        navigateFallback: "/index.html",
        runtimeCaching: [
          {
            urlPattern: ({ request }) => request.destination === "image",
            handler: "CacheFirst",
            options: { cacheName: "images-cache" },
          },
          {
            urlPattern: ({ url }) => url.pathname.startsWith("/rest/v1/"),
            handler: "NetworkFirst",
            options: { cacheName: "api-cache" },
          },
        ],
      },
      manifest: {
        name: "Campus Glide",
        short_name: "CampusGlide",
        description: "Campus Glide progressive web app",
        theme_color: "#27af30",
        background_color: "#ffffff",
        display: "standalone",
        start_url: "/",
        icons: [
          {
            src: "/icon-192x192.png",
            sizes: "192x192",
            type: "image/png",
            purpose: "any",
          },
          {
            src: "/icon-512x512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "any",
          },
        ],
      },
    }),
  ],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  // Keep the port fixed so it always matches FRONTEND_URL in the backend CORS config.
  server: {
    port: 5173,
    strictPort: true,
  },
});
