#!/usr/bin/perl
#
# Install initrd scripts
#

my %depends = ();
my %providedby = ();

sub resolve_dependency
{
    my $name = shift(@_);
    my $oldname = shift(@_);
    my $oldlevel = $level{$name};

    foreach $elem (split(' ',$depends{$name})) {
	my $newlevel = -1;

	foreach $n (split(' ',$providedby{$elem})) {
	    $newlevel = resolve_dependency($n, $name);
	    if ( $oldlevel <= $newlevel) {
		$oldlevel = $newlevel + 1;
	    }
	}

	if ($newlevel == -1) {
	    print "Unresolved dependency \"$elem\" ";
	}
    }
    print "$name ($oldlevel) ";
    $level{$name} = $oldlevel;

    return $oldlevel;
}

sub scan_section
{
    my $section = shift(@_);
    my @scrlist = ();

    %depends = ();
    %providedby = ();

    SCAN: foreach $_ (@scripts) {
	my $provides;

	if (/(.*)-(.*)\.sh$/) {
	    if ($1 ne $section ) {
		next SCAN;
	    }
	    $section = $1;
	    $scriptname = $2;
	} else {
	    next SCAN;
	}

	print "scanning script $_ (name $scriptname)\n";
	printf "\tsection: %s\n", $section;
	$provides = $scriptname;

	open(SCR, "$scriptdir/$_");

	while (<SCR>) {
	    chomp;
	    if ( /^\#%stage: (.*)/ ) {
		if (!defined ($stages{$1})) {
		    printf "%s: Invalid stage \"%s\"\n", $scriptname, $1;
		    close(SCR);
		    next SCAN;
		}
		if ($section eq "setup") {
		    $level{$scriptname} = ($stages{$1} * 10) + 1;
		} else {
		    $level{$scriptname} = 91 - ($stages{$1} * 10);
		}
		printf "\tstage %s: %d\n", $1, $level{$scriptname};
	    }
	    if ( /^\#%depends: (.*)/ ) {
		printf "\tdepends on %s\n", $1;
		$depends{$scriptname} = $1;
	    }
	    if ( /\#%provides: (.*)/ ) {
		$provides = join(' ',$provides,$1);
	    }

	}
	close SCR;

	@scrlist = (@scrlist,$scriptname);

	printf "\tprovides %s\n", $provides;
	foreach $elem (split(' ',$provides)) {
	    $providedby{$elem} = join(' ', $providedby{$elem},$scriptname);
	}
    }

    return @scrlist;
}

$offset=1;
$installdir="lib/mkinitrd";
$scriptdir="scripts";

$stagefile = "$installdir/stages";
open(STAGE, $stagefile) or die "Can't open $stagefile";

# Generate levels
$level=0;
while(<STAGE>) {
    chomp;
    next if ( /\#.*/ );
    my ($name,$comment) = split / /;
    next if $name eq "";
    $stages{$name} = $level;
    printf "Found stage %s: %d\n", $name, $stages{$name} ;
    $level++;
}
close(STAGE);

opendir(DIR, $scriptdir);
@scripts = grep { /.*\.sh$/ && -f "$scriptdir/$_" } readdir(DIR);
closedir DIR;

# First round: setup scripts
$section = "setup";
@setup = scan_section($section);

# Resolve dependencies
foreach $scr (@setup) {
    resolve_dependency($scr);
    print "\n";
}

# Print result
foreach $name (@setup) {
    my $level = $level{$name};

    printf "%s/%02d-$name.sh\n", $section, $level, $name;
}

# Second round: boot scripts
$section = "boot";
@boot = scan_section($section);

# Resolve dependencies
foreach $scr (@boot) {
    resolve_dependency($scr);
    print "\n";
}

# Print result
foreach $name (@boot) {
    my $level = $level{$name};

    printf "%s/%02d-$name.sh\n", $section, $level, $name;
}

