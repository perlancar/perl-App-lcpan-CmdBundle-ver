package App::lcpan::Cmd::ver_cmp_list;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

require App::lcpan;

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'Compare a list of module names+versions against database',
    args => {
        %App::lcpan::common_args,
        list => {
            summary => 'List of module names and versions, one per line',
            description => <<'_',

Each line should be in the form of:

    MODNAME VERSION

_
            schema => 'str*',
            req => 1,
            cmdline_src => 'stdin_or_files',
        },
        show => {
            schema => ['str*', in=>[
                'unknown-in-db',
                'newer-than-db',
                'older-than-db',
                'same-as-db',
                'all',
            ]],
            default => 'older-than-db',
            cmdline_aliases => {
                'unknown_in_db' => {
                    is_flag=>1,
                    summary => 'Shortcut for --show unknown-in-db',
                    code=>sub { $_[0]{show} = 'unknown-in-db' },
                },
            },
            cmdline_aliases => {
                'unknown_in_db' => {
                    is_flag=>1,
                    summary => 'Shortcut for --show unknown-in-db',
                    code=>sub { $_[0]{show} = 'unknown-in-db' },
                },
                'newer-than-db' => {
                    is_flag=>1,
                    summary => 'Shortcut for --show newer-than-db',
                    code=>sub { $_[0]{show} = 'newer-than-db' },
                },
                'older-than-db' => {
                    is_flag=>1,
                    summary => 'Shortcut for --show older-than-db',
                    code=>sub { $_[0]{show} = 'older-than-db' },
                },
                'same-as-db' => {
                    is_flag=>1,
                    summary => 'Shortcut for --show same-as-db',
                    code=>sub { $_[0]{show} = 'same-as-db' },
                },
                'all' => {
                    is_flag=>1,
                    summary => 'Shortcut for --show same-as-db',
                    code=>sub { $_[0]{show} = 'all' },
                },
            },
        },
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $show = $args{show};

    my %mods_from_list; # key=name, val=version
    my $i = 0;
    for my $line (split /^/, $args{list}) {
        $i++;
        unless ($line =~ /^\s*(\w+(?:::\w+)*)(?:\s+([0-9][0-9._]*))?/) {
            $log->errorf("Syntax error in list line %d: %s, skipped",
                         $i, $line);
            next;
        }
        $mods_from_list{$1} = $2 // 0;
    }

    my %mods_from_db;
    {
        last unless %mods_from_list;
        my $sth = $dbh->prepare(
            "SELECT name, version FROM module WHERE name IN (".
                join(",", map {$dbh->quote($_)} keys %mods_from_list).")");
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            $mods_from_db{$row->{name}} = $row->{version};
        }
    }

    my @res;
    my $resmeta = {};
    if ($show eq 'unknown-in-db') {
        for (sort keys %mods_from_list) {
            push @res, $_ unless exists $mods_from_db{$_};
        }
    } else {
        for (sort keys %mods_from_list) {
            next unless exists $mods_from_db{$_};
            my $cmp = version->parse($mods_from_list{$_}) <=>
                version->parse($mods_from_db{$_});
            if ($show eq 'newer-than-db') {
                next unless $cmp == 1;
                $resmeta->{'table.fields'} = [qw/module input_version db_version/] unless @res;
                push @res, {module=>$_, db_version=>$mods_from_db{$_}, input_version=>$mods_from_list{$_}};
            } elsif ($show eq 'older-than-db') {
                next unless $cmp == -1;
                $resmeta->{'table.fields'} = [qw/module input_version db_version/] unless @res;
                push @res, {module=>$_, db_version=>$mods_from_db{$_}, input_version=>$mods_from_list{$_}};
            } elsif ($show eq 'same-as-db') {
                next unless $cmp == 0;
                $resmeta->{'table.fields'} = [qw/module version/] unless @res;
                push @res, {module=>$_, version=>$mods_from_db{$_}};
            } else {
                $resmeta->{'table.fields'} = [qw/module input_version db_version/] unless @res;
                push @res, {module=>$_, db_version=>$mods_from_db{$_}, input_version=>$mods_from_list{$_}};
            }
        }
    }

    [200, "OK", \@res, $resmeta];
}

1;
# ABSTRACT:
