# The game checker -- separate from the agent image, on purpose.
#
# There is a browser in here. Inside the agent container it would be a tool
# available to the model: it could open its own game and patch it up. That
# would be a different harness than the one we mean to measure. So a second
# container checks, after the agent has finished and exited.
FROM node:22-slim

# A shared location for the browser. Without it Playwright puts it in the
# building user's cache (root) and the working user cannot find it -- the same
# pattern as aider's Python under /root/.local.
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
RUN npm install -g playwright@1.56.0 \
 && npx playwright install --with-deps chromium \
 && chmod -R a+rX /opt/ms-playwright \
 && rm -rf /var/lib/apt/lists/*

COPY vorpruefung.js laufzeit.js /opt/pruefen/
# node:22-slim already ships a user with uid 1000 ("node") -- creating a
# second one fails. Using the existing one is right anyway: the files in the
# run directory belong to that same uid.
RUN chown -R node:node /opt/pruefen
USER node
ENV NODE_PATH=/usr/local/lib/node_modules
WORKDIR /arbeit
