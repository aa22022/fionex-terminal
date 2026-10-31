FROM julia:1.10-bookworm

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y curl ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY Project.toml ./

# Install Julia packages (force add + instantiate)
RUN julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"

# Copy source code
COPY src/ ./src/
COPY templates/ ./templates/
COPY static/ ./static/

# Create data directory
RUN mkdir -p data

# Port configuration
EXPOSE 10000
ENV PORT=10000

# Run server
CMD ["julia", "--project=.", "src/main.jl"]
