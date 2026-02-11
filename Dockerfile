# Start from the official n8n image
FROM n8nio/n8n:latest

# Switch to root to install packages
USER root

# Install bash and jq (needed for the run script)
RUN apk add --no-cache bash jq

# Copy our run script
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Switch back to the node user (optional, but n8n prefers non-root)
# Note: HA Add-ons often run as root to access hardware/config, 
# but for n8n we usually want to stay as 'node'. 
# However, to read HA config options easily, running as root is simpler.
# Let's stay root for the wrapper script, then drop down if needed.
USER root

CMD [ "/run.sh" ]