  #!/bin/bash
export PGPASSWORD=$([ -f $PGDATA/pg_pass ] && cat $PGDATA/pg_pass || LC_CTYPE=C tr -dc A-Za-z0-9_\!\@\#\$\%\^\&\*\(\)-+= < /dev/urandom | head -c 32 | xargs)

if [ "$1" = 'postgres' ]; then
    chown -R postgres "$PGDATA"

    if [ -z "$(ls -A "$PGDATA")" ]; then
        # Password file
        echo $PGPASSWORD > /pg_pass 
        chown postgres /pg_pass 
        chmod 700 /pg_pass
        # Init DB
        echo "Creating user $PGUSER:$PGPASSWORD"
        gosu postgres initdb -U $PGUSER --pwfile=/pg_pass 
        # Move to $PGDATA to persist
        mv /pg_pass $PGDATA
        # Create database
        gosu postgres postgres --single <<< "CREATE DATABASE $PGDATABASE ENCODING 'UTF8' TEMPLATE template0;"

        sed -ri "s/^#(listen_addresses\s*=\s*)\S+/\1'*'/" "$PGDATA"/postgresql.conf
        
        { echo; echo 'host all all 0.0.0.0/0 md5'; } >> "$PGDATA"/pg_hba.conf
        { echo; echo 'host replication postgres 0.0.0.0/0 trust'; } >> "$PGDATA"/pg_hba.conf

        #Reload db
        gosu postgres postgres --single <<< "select pg_reload_conf();"
    fi
    
    exec gosu postgres "$@"
fi

exec "$@"
