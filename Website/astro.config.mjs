import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://dontunplugthat.com',
  output: 'static',
  outDir: './dist/client',
  devToolbar: { enabled: false },
});
