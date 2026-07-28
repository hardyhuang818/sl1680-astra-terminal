#!/bin/bash
# Compile no_openat2 and generate hosttools wrappers that route fakeroot-tree
# tools through it (forces openat2->ENOSYS so pseudo can track dir fds).
set -e
gcc -O2 -o /home/astra/no_openat2 /home/astra/no_openat2.c
echo "compiled: /home/astra/no_openat2"

mkdir -p /home/astra/toolwrap
for t in tar cp rsync install mv ln mkdir cpio bzip2 gzip pigz; do
    real=$(command -v "$t" 2>/dev/null)
    [ -z "$real" ] && continue
    cat > "/home/astra/toolwrap/$t" <<EOF
#!/bin/sh
exec /home/astra/no_openat2 $real "\$@"
EOF
    chmod +x "/home/astra/toolwrap/$t"
done

echo "wrappers:"
ls -1 /home/astra/toolwrap/
echo "--- tar wrapper ---"
cat /home/astra/toolwrap/tar
