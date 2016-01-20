package App::lcpan::Cmd::ver_cmp_installed;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use ExtUtils::MakeMaker;
use Function::Fallback::CoreOrPP qw(clone);

require App::lcpan;
require App::lcpan::Cmd::ver_cmp_list;

our %SPEC;

$SPEC{handle_cmd} = do {
    my $meta = clone($App::lcpan::Cmd::ver_cmp_list::SPEC{handle_cmd});
    $meta->{summary} = 'Compare installed module versions against database';
    delete $meta->{args}{list};
    $meta;
};
sub handle_cmd {
    require PERLANCAR::Module::List;

    my %args = @_;

    my $mod_paths = PERLANCAR::Module::List::list_modules(
        "", {list_modules=>1, recurse=>1, return_path=>1},
    );

    my @list;
    for my $mod (sort keys %$mod_paths) {
        my $ver = MM->parse_version($mod_paths->{$mod});
        $ver = "" if defined($ver) && $ver eq 'undef';
        push @list, "$mod\t$ver\n";
    }

    App::lcpan::Cmd::ver_cmp_list::handle_cmd(%args, list=>join("", @list));
}

1;
# ABSTRACT:

=head1 SEE ALSO

L<App::cpanoutdated>
