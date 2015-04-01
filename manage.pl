#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Pod::Usage;

my $VERSION = '0.2';
my %infohashes;;
my %opts = ('whitelist' => '/var/www/tracker/whitelist.txt');

sub verbose {
    return unless($opts{'verbose'});
    my $msg = shift;
    print "[VERBOSE] $msg\n";
}

sub load_whitelist {
    verbose('Cleaning hash list.');
    delete($infohashes{$_}) foreach (keys %infohashes);

    verbose('Loading whitelist: '. $opts{'whitelist'});
    open IN, '<', $opts{'whitelist'};
    while(<IN>) {
        chomp;

        s/;.+\n//g;             ## Remove stuff that hasn't been removed from this script.

        if( /^\s*$/ or length($_) == 0 ) {
            verbose('Found an empty line; skipping.');
            next;
        }

        ## Found a good hash
        if(/[0-9a-f]{20}/i) {
            ## This removes duplicates
            $infohashes{$_} = 1;
            verbose('Found hash: '. $_);
        } else {
            print "Found a non-hash: '$_'\n";
        }
    }
    close IN;
}

sub save_whitelist {
    verbose('Saving whitelist: '. $opts{'whitelist'});
    open OUT, '>', $opts{'whitelist'};
    foreach my $hash ( keys %infohashes ) {
        print OUT $hash, "\n";
    }
    close OUT;

    ## Send a SIGHUP to the tracker processes
    hup_server();
}

sub remove_hash {
    load_whitelist();
    my @remHash = @_;

    for my $h ( @{$remHash[0]} ) {
        $h = uc $h;
        verbose('Attempting to remove '. $h. ' from the whitelist.');

        unless($h =~ /[0-9a-f]{20}/i) {
            verbose('Was not a hash; skipping.');
            return;
        }

        if( $infohashes{$h} ) {
            delete $infohashes{$h};
            verbose('Removal successfull.');
        } else {
            print "Hash not found.\n";
        }
    }
    save_whitelist();
}

sub add_hash {
    load_whitelist();
    my @addHash = @_;

    for my $h (@{$addHash[0]}) {
        $h = uc $h;
        verbose('Attempting to add '. $h. ' to the whitelist');
        unless($h =~ /[0-9a-z]{20}/i) {
            print "Invalid hash: '$h'\n";
            return;
        }

        $infohashes{$h} = 1;
        verbose('Addition successfull.');
    }
    save_whitelist();
}

sub hup_server {
    ## NOTE: I've removed this from my fork of opentracker.  I've moved to
    ## using inotify instead of sending SIGHUP signals as it would crash my
    ## server.  Uncomment the system call here to restore this
    ## functionality.

    ## Sending a SIGHUP to both processes tells them to reload the whitelist file.
    #verbose('Sending a SIGHUP to all \'opentracker\' processes.');
    #system('pkill', '-1', 'opentracker');
    verbose('ignoring hup');
}

sub list_hashes {
    load_whitelist();
    my @hashes = keys %infohashes;
    foreach my $h ( @hashes ) {
        print "$h\n";
    }

    print "\n". ($#hashes + 1). " hashes found.\n";
}

Getopt::Long::Configure("bundling");
GetOptions(\%opts, 'verbose|v', 'add|a=s@', 'remove|r=s@', 'list|l', 'huponly|h', 'whitelist|w=s');

if(defined($opts{'huponly'})) {
    print("Server uses inotify.  Sending SIGHUP is disabled.\n");
    exit(1);
}

my $didsomething = 0;

verbose('Using whitelist: '. $opts{'whitelist'});

if(defined($opts{'add'})) {
    add_hash($opts{'add'});
    $didsomething = 1;
}

if(defined($opts{'remove'})) {
    remove_hash($opts{'remove'});
    $didsomething = 1;
}

if(defined($opts{'list'})) {
    list_hashes();
    $didsomething = 1;
}

unless($didsomething == 1) {
    pod2usage(
        -message => "======\n== Error: No action performed!\n======\n",
        -verbose => 1,
        -noperldoc => 1,
    );
}


__END__

=head1 NAME

manual-add-remove.pl

=head1 SYNOPSIS

=over 4

=item manual-add-remove.pl <options>

Manually add and remove hashes from opentracker.

=back

=head1 OPTIONS

=over 4

=item --add <hash>

=item -a <hash>

Add the given hash to the whitelist.  This can be used multiple times.

=item --huponly

=item -h

Don't add or remove anything, just make the server refresh the whitelist.  All other arguments are ignored if this is specified.

=item --list

=item -l

List all the hashes currently served.

=item --remove <hash>

=item -r <hash>

Remove the given hash from the whiletlist.  This can be used multiple times.

=item --verbose

=item -v

Print B<everything>.  Chances are you don't want this.

=item --whitelist <file>

=item -w <file>

By default 'whitelist.txt' is used in the current directory.  Use this to change that.

=back

=head1 EXAMPLES

=over 4

=item Adding multiple hashes

manual-add-remove.pl --add b4b56d63aed238d91377576876c9489b2f39ffef --add 5492ad2882059c73b7bb7ff8dfe27930c7d6ba39

=item Removing multiple hashes

manual-add-remove.pl --remove b4b56d63aed238d91377576876c9489b2f39ffef --remove 5492ad2882059c73b7bb7ff8dfe27930c7d6ba39

=item Adding and removing hashes

manual-add-remove.pl --add b4b56d63aed238d91377576876c9489b2f39ffef --remove 5492ad2882059c73b7bb7ff8dfe27930c7d6ba39

=cut

