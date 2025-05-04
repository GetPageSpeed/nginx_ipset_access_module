# NGINX IPSet Access Module

A high‑performance NGINX module that lets you **whitelist** or **blacklist** client IP addresses using the Linux **ipset** kernel facility.  
All look‑ups are made in userspace via `libipset` and cached *per worker thread* to minimise overhead.

---

## Features

* **Zero‑runtime overhead** – IPSet sessions are initialised once and cached with thread‑local storage.  
* **Whitelist & Blacklist modes** – block everything except the listed sets, or allow everything except the listed sets.  
* **Dynamic updates** – modifying an `ipset` does **not** require an NGINX reload.  
* **Native RPM packages** for RHEL / Alma / Rocky and derivatives via GetPageSpeed repository.

---

## How it works

```text
┌ Client ──► NGINX worker
│             │
│             ├─► Thread‑local ipset session (libipset)
│             │      ├─ Test client IP against one or more sets
│             │      └─ Cache session handle for reuse
│             │
└─────────────┴── Allow / Deny based on match & mode
```

The module:

1. Initialises `libipset` once per worker process.  
2. Caches a session handle in POSIX thread‑specific data (`pthread_setspecific`).  
3. Evaluates the client’s IPv4 address (`AF_INET`) against each configured set.  
4. Returns **403 Forbidden** (or custom code *444* when `blacklist` mode is selected and the IP matches).

---

## Requirements

* NGINX ≥ 1.22 (compiled with standard module API).  
* Linux with **ipset** support (`nf_tables` or `ipset` kernel module).  
* `libipset` development headers at build‑time.

---

## Quick installation (RPM‑based distributions)

```bash
sudo dnf --assumeyes install https://extras.getpagespeed.com/release-latest.rpm
sudo dnf --assumeyes install nginx-module-ipset-access
```

> **Tip:** The package is signed; make sure you have `gpgcheck=1` enabled.

Enable the module in **`/etc/nginx/nginx.conf`** **before** any `http {}` blocks:

```nginx
load_module modules/ngx_http_ipset_access.so;
```

Reload NGINX to apply:

```bash
sudo systemctl reload nginx
```

---

## Building from source

```bash
# Install build dependencies
sudo dnf group install --assumeyes "Development Tools"
sudo dnf --assumeyes install libipset-devel pcre2-devel zlib-devel openssl-devel

# Clone NGINX and the module
git clone https://github.com/nginx/nginx.git
git clone https://example.com/ngx_ipset_access.git

cd nginx
./auto/configure   --with-compat   --add-dynamic-module=../ngx_ipset_access
make -j$(nproc)
sudo make install
```

The build produces `objs/ngx_http_ipset_access.so`; copy it to your NGINX *modules* directory and add `load_module` as shown above.

---

## Configuration Directives

### `blacklist` *set1* [*set2* …*setN*]

*Context*: `http`, `server`  
Blocks requests **if the client IP appears in **any** of the listed ipset(s)**.

### `whitelist` *set1* [*set2* …*setN*]

*Context*: `http`, `server`  
Allows requests **only if the client IP appears in a listed set**. All other IPs are rejected.

### `off`

Either directive accepts the literal word `off` to disable processing for the current context:

```nginx
server {
    listen 80;
    blacklist off;   # no ipset filtering in this virtual‑host
}
```

---

## Example usage

```bash
# Create an ipset of blocked addresses
sudo ipset create bad_guys hash:ip
sudo ipset add bad_guys 203.0.113.4
sudo ipset add bad_guys 198.51.100.23
```

```nginx
load_module modules/ngx_http_ipset_access.so;

http {
    # Block any IP found in "bad_guys"
    blacklist bad_guys;

    server {
        listen 80 default_server;
        root /usr/share/nginx/html;
    }
}
```

Because look‑ups are *live*, adding or removing IPs from `bad_guys` takes effect instantly without reloading NGINX.

---

## Logging & debugging

Build NGINX with `--with-debug` and set `error_log /var/log/nginx/error.log debug;` to see verbose output such as:

```text
test bad_guys 203.0.113.4 -> IPS_TEST_IS_IN_SET
Blocking 203.0.113.4 due to IPSET
```

---

## Return codes

| Mode        | IP match result        | HTTP status |
|-------------|------------------------|-------------|
| `whitelist` | Not in any set         | **403** |
| `blacklist` | In a configured set    | **403** (module can be patched to 444) |
| Any         | Error contacting ipset | **403** (treated as deny for safety) |

---

## Limitations & Roadmap

* IPv4 only – `AF_INET6` is not yet supported.  
* Uses synchronous libipset calls; at very high request rates the kernel may be faster with `nft set` rules alone.  
* Custom return status **444** is prepared but commented; enable if you need drop‑without‑reply semantics.

---

## Contributing

1. Fork the repository  
2. Create a feature branch  
3. Submit a pull‑request following the [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow).

Please run `clang-format` before committing.

---

## License

MIT – see `LICENSE`.

---

## Author

Mohammad Mahdi Roozitalab <mehdiboss_qi@hotmail.com>  
RPM packaging & documentation maintained by GetPageSpeed.
