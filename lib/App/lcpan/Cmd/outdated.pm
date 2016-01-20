package App::lcpan::Cmd::outdated;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use ExtUtils::MakeMaker;

require App::lcpan;

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'lcpan version of cpan-outdated',
    description => <<'_',

Like `cpan-outdated` utility, this subcommand also checks the versions of
installed modules and compares them against the database. If the installed
version is older, will show the release files. The output can then be fed to
`cpanm`, for example.

Thanks to the data already in SQLite format, it can be faster than
`cpan-outdated`.

_
    args => {
        %App::lcpan::common_args,
    },
};
sub handle_cmd {
    require PERLANCAR::Module::List;

    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $mod_paths = PERLANCAR::Module::List::list_modules(
        "", {list_modules=>1, recurse=>1, return_path=>1},
    );

    my %mods_from_db;
    my %file_mods; # key=filename, val=(hash key=)
    {
        last unless %$mod_paths;
        my $sth = $dbh->prepare("
SELECT
  name, version, cpanid,
  (SELECT name FROM file WHERE id=file_id) fname
FROM module WHERE name IN (".
                join(",", map {$dbh->quote($_)} keys %$mod_paths).")");
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            $row->{fname} = join(
                "",
                substr($row->{cpanid}, 0, 1), "/",
                substr($row->{cpanid}, 0, 2), "/",
                $row->{cpanid}, "/",
                $row->{fname},
            );
            $mods_from_db{$row->{name}} = $row;
            $file_mods{$row->{fname}}{$row->{name}}++;
        }
    }

    my @res;
    my %done_mods;
    for my $mod (sort keys %$mod_paths) {
        next if $done_mods{$mod};
        next unless exists $mods_from_db{$mod};

        my $fname = $mods_from_db{$mod}{fname};

        # mark all modules from the same file as done
        for (keys %{ $file_mods{$fname} }) { $done_mods{$_}++ }

        my $ver = MM->parse_version($mod_paths->{$mod});
        $ver = 0 if !defined($ver) || defined($ver) && $ver eq 'undef';

        my $cmp = version->parse($ver) <=>
            version->parse($mods_from_db{$mod}{version});
        next unless $cmp == -1;

        push @res, $fname;
    }

    [200, "OK", \@res];
}

1;
# ABSTRACT:
