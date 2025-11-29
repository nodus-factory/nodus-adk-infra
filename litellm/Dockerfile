# Custom LiteLLM image with libsndfile for Whisper/Groq audio transcription
FROM ghcr.io/berriai/litellm:main-latest

# Install libsndfile for audio file processing (required by Groq Whisper)
USER root
RUN apk add --no-cache libsndfile
USER 2000

# Default command (can be overridden in docker-compose.yml)
CMD ["--config", "/app/config/litellm_config.yaml", "--port", "4000", "--detailed_debug"]

