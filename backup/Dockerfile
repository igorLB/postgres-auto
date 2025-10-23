FROM postgres:17-alpine

# The postgres image already contains the client tools (pg_dumpall).
# We only need bash for the script and tzdata for predictable timestamps.
RUN apk add --no-cache bash tzdata

# Copy the entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["once"]
