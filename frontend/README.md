# Frontend

React app, built with [Vite](https://vite.dev).

## Available Scripts

### `npm run dev`

Runs the app in development mode on [http://localhost:3000](http://localhost:3000), with hot module reload.

### `npm run build`

Builds the app for production to the `dist` folder.

### `npm run preview`

Serves the production build from `dist` locally, to sanity-check it before deploying.

### `npm test`

Runs the test suite once (Vitest).

### `npm run lint`

Runs ESLint.

## Configuration

`VITE_API_BASE_URL` (see `.env`) is the backend base URL. Vite inlines it at build time, so to point a built image at a different backend, pass it as a Docker build arg rather than an environment variable at container start (see the root `compose.yml`).
