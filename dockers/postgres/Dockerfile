#
# Postgres dockerfiles, with username, database customizable from env variable
#
FROM postgres:latest
MAINTAINER Quyet Nguyen (quyet@plz.vn)

# Add environments 
ENV PGDATABASE vov
ENV PGUSER vov
    
# Use OUR scripts
RUN rm /docker-entrypoint.sh
ADD ./docker-entrypoint.sh /
RUN chmod 700 /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["postgres"]