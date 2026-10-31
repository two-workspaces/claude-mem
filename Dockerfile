# claude-mem server for Railway: upstream's docker/claude-mem/Dockerfile, built
# from a pinned release tag, minus the Claude Code CLI (the server's claude
# provider calls the Messages API directly) and with a first-boot key setup.
# upgrade: github thedotmack/claude-mem
ARG CLAUDE_MEM_VERSION=v15.7.0

# upgrade: skip
FROM node:20-bookworm
ARG CLAUDE_MEM_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl ca-certificates unzip \
 && rm -rf /var/lib/apt/lists/*

ARG BUN_VERSION=1.3.12
ENV BUN_INSTALL=/usr/local/bun PATH=/usr/local/bun/bin:$PATH
RUN curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}" && chmod -R a+rX /usr/local/bun

RUN git clone --depth 1 --branch "${CLAUDE_MEM_VERSION}" https://github.com/thedotmack/claude-mem /tmp/src \
 && mv /tmp/src/plugin /opt/claude-mem && rm -rf /tmp/src \
 && chown -R node:node /opt/claude-mem

USER node
# Same as upstream: skip onnxruntime's CUDA provider, bake the default embedding model.
RUN cd /opt/claude-mem \
 && ONNXRUNTIME_NODE_INSTALL_CUDA=skip npm install --omit=dev --legacy-peer-deps \
 && npm cache clean --force \
 && node -e "import('@huggingface/transformers').then(t => t.pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2', { dtype: 'fp32' }))"

USER root
RUN mkdir -p /home/node/.claude-mem /data/claude-mem && chown -R node:node /home/node/.claude-mem /data/claude-mem
COPY --chown=node:node railway-setup.mjs /opt/railway-setup.mjs
COPY --chmod=755 railway-entrypoint.sh /usr/local/bin/railway-entrypoint

USER node
WORKDIR /home/node
ENV CLAUDE_MEM_DOCKER=1 \
    CLAUDE_MEM_RUNTIME=server-beta \
    CLAUDE_MEM_QUEUE_ENGINE=bullmq \
    CLAUDE_MEM_REDIS_MODE=docker \
    CLAUDE_MEM_AUTH_MODE=api-key \
    CLAUDE_MEM_CHROMA_ENABLED=false \
    CLAUDE_MEM_HOST=0.0.0.0 \
    CLAUDE_MEM_SERVER_HOST=0.0.0.0 \
    CLAUDE_MEM_WORKER_HOST=0.0.0.0 \
    CLAUDE_MEM_DATA_DIR=/data/claude-mem

ENTRYPOINT ["/usr/local/bin/railway-entrypoint"]
