%define TarBall PersonalPerlLibrary-Mail

Summary: PersonalPerlLibrary-Mail PERL library
Name: perl-%{TarBall}
Version: 0.16
Release: RHEL4
Copyright: GPL
Group: System Development/Languages
Distribution: RHEL 4 AS
Source: file://usr/src/redhat/SOURCES/%{TarBall}-%{version}.tar.gz
Packager: Jose Angel de Bustos Perez <jadebustos@gmail.com>
BuildRequires: perl make
Requires: perl perl-File-Type perl-Mail-IMAPClient perl-PersonalPerlLibrary-FS

%description
PerlPersonalLibrary is my own set of PERL functions.

%prep

%setup -n %{TarBall}-%{version}
perl Makefile.PL

%install
make install

%files

%defattr(-,root,root)

/usr/lib/perl5/site_perl/5.8.5/PersonalPerlLibrary/Mail.pm

# Documentacion

#%doc /usr/share/man/man3/Net::Ping::External.3pm

%clean
rm -Rf $RPM_BUILD_DIR/%{name}-%{version}
