# DNSBlockBuster

DNSBlockBuster is a shell script that creates a DNS blacklist for Unbound and dnsmasq from a bunch of DNS host lists.

The DNS hosts lists are used to block ads, porn sites, tracking and other domains.

## Information about redirecting

When you're dealing with DNS domain blocking you have multiple choice on how to handle a blocked domain.

Some people redirect the domain to 127.0.0.1, which is the IP address of the loopback interface, others redirect to 0.0.0.0, which means "This host on this network", both options work but is the wrong approach. Whether you redirect to [127.0.0.1 or 0.0.0.0](https://tools.ietf.org/html/rfc6890#section-2.2.2) the redirect will cause the client to connect to itself.

The correct approach is to use the [NXDOMAIN](https://tools.ietf.org/html/draft-ietf-dnsop-nxdomain-cut-05) reply which means that the domain name which is denied and all the names under it do not exist. Even if the domain actually do exists on the Internet, since it is being blocked by the DNS server, it doesn't exist to the client doing the query.

When we use NXDOMAIN responses instead of redirecting to 0.0.0.0 or 127.0.0.1 we also save memory on the DNS server that would otherwise be spent mapping each domain to one of these IP addresses.

Unbound handles huge lists of NXDOMAINS very well, but it doesn't handle redirect lists to IP addresses like 0.0.0.0 well. Redirects to IP addresses requires both a `local-zone` and a `local-data`. This means that Unbound should always be used with the NXDOMAIN reply anyway.

On dnsmasq it is opposite. dnsmasq can handle huge files with many millions of hosts with redirects to 0.0.0.0 very well, it requires very little memory and is very fast. It does this with the `--addn-hosts` option. However, NXDOMAIN doesn't work with the `--addn-hosts` option, only the `--servers-file` option. The `--servers-file` only takes entries that contain the `server=` option, but dnsmasq is extremely bad at handling huge lists with the `server=` option, it becomes very very slow.

This means that if you're using dnsmasq with huge hosts lists, like the ones in this script (you can remove lists you don't want), then don't use NXDOMAIN even if it is the right thing to do. dnsmasq will have horrible response times.

Many people have requested the adding of NXDOMAIN to dnsmasq's `--addn-hosts` option (such as this: <https://www.mail-archive.com/dnsmasq-discuss@lists.thekelleys.org.uk/msg06920.html>), but it has never been implemented. Someone eventually [forked dnsmasq](https://code.google.com/archive/p/dnsmasq-guard/) and added the option to create a blacklist of domains that will get the NXDOMAIN reply, but that work has been discontinued.

So, if you're going to handle a huge list of domains with dnsmasq, you're better of using the `addn-hosts` option and then redirect to 0.0.0.0 rather than using the `server=` option, even if this doesn't provide you with a NXDOMAIN reply. If the block list is small you can use the `server=` option, but this script doesn't do that.

One caveat about using NXDOMAIN in general is that you cannot immediately tell if the response came from an upstream DNS server or if the reply came from your local DNS server. You have to check with something like `drill` when you want to know that.

## Unbound timeout

If you use all the DNS block lists that is available in this script you may need to increase the timeout parameter for Unbound.

On OpenBSD it is done in `/etc/rc.conf.local`:

```
unbound_flags=
unbound_timeout=240
```

Check the documentation for how to set the timeout on the operating system you're using.

## Notes before usage

Please note that some of the regular expressions in the script are CPU hungry. If you run dnsmasq or Unbound on a slow device you're advised to run this script on a faster computer and then transfer the resulting host block files.

More list can be found at [The Firebog](https://firebog.net/)

Feel free to contribute!

## Usage

By default DNSBlockBuster uses a list of online hosts files listed in [online-hosts-files.txt](online-hosts-files.txt), these are the default hosts files. If you don't want to use those, or simply want to remove or add some, copy the file into a new one called `personal-online-hosts-files.txt` and edit that to suit your needs.

Make the script executable:

```
$ chmod +x dnsblockbuster
```

Then generate the DNS block files by running the script:

```
$ ./dnsblockbuster
```

DNSBlockBuster creates two files. `unbound-blocked-hosts.conf` is for usage with Unbound, while `dnsmasq-blocked-hosts.conf` is for dnsmasq.

When the script has finished generating the hosts files you need to include those.

In `unbound.conf` you include the host file with (change your path to fit you needs):

```
include: "/var/unbound/etc/unbound-blocked-hosts.conf"
```

In `dnsmasq` use the `addn-host` option in `dnsmasq.conf` (change your path to fit you needs):

```
addn-hosts=/etc/dnsmasq-blocked-hosts.conf
```

Reload or restart the DNS server.

### Whitelist and personal blacklist

If you need to whitelist some domains, create a file called `whitelist.txt` and add each domain on a single line without any whitespace between, like this:

```
example.org
example.com
```

DNSBlockBuster will automatically remove the whitelisted entries.

If you want to add some domains to the block list that isn't already located in any of the online host files that gets downloaded, create a file called `blacklist.txt` and add the domains to that like in the whitelist.

## Trouble shooting the block lists

DNSBlockBuster tries to clear out mistakes in the input hosts files, but occasionally they contain something which is wrong. Always check the lists before usage.

On Unbound use:

```
# unbound-checkconf
```

On dnsmasq use:

```
dnsmasq --test
```

dnsmasq is more forgiving than Unbound.

If you do get an error you need to do some "bug hunting". I advice that you use `grep` to try and find the error.

For the Unbound block list you can catch any line with wrong syntax using:

```
# grep -rn '^local-zone: "*" always_nxdomain$' unbound-blocked-hosts.conf | more
```

You can also check the dnsmasq block list for any lines that, for example, doesn't begin with 0.0.0.0:

```
# grep rnv "^0.0.0.0" dnsmasq-blocked-hosts.txt
```

Both Unbound and dnsmasq will simply ignore duplicates, and DNSBlockBuster tries to remove any duplicate entries, but if you need to, you can manually locate them with:

```
# sort unbound-blocked-hosts.conf | uniq -cd
```

## Dependencies

- [wget](https://www.gnu.org/software/wget/)
