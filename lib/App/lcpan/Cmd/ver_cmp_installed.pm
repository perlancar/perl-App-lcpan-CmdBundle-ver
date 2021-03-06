package App::lcpan::Cmd::ver_cmp_installed;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use ExtUtils::MakeMaker;
use Function::Fallback::CoreOrPP qw(clone);

require App::lcpan;
require App::lcpan::Cmd::ver_cmp_list;

our %SPEC;

$SPEC{handle_cmd} = do {
    my $meta = clone($App::lcpan::Cmd::ver_cmp_list::SPEC{handle_cmd});
    $meta->{summary} = 'Compare installed module versions against database';
    delete $meta->{args}{list};
    $meta->{args} = {
        %{ $meta->{args} },
        %App::lcpan::finclude_core_args,
        %App::lcpan::finclude_noncore_args,
    };
    $meta;
};
sub handle_cmd {
    require Module::CoreList::More;
    require PERLANCAR::Module::List;

    my %args = @_;
    my $include_core    = $args{include_core} // 1;
    my $include_noncore = $args{include_noncore} // 1;

    my $mod_paths = PERLANCAR::Module::List::list_modules(
        "", {list_modules=>1, recurse=>1, return_path=>1},
    );

    my @list;
    for my $mod (sort keys %$mod_paths) {
        my $ver = MM->parse_version($mod_paths->{$mod});
        $ver = 0 if defined($ver) && $ver eq 'undef';
        eval { $ver = version->parse($ver)->numify };
        if ($@) { warn; $ver = 0 }

        my $is_core = Module::CoreList::More->is_still_core(
            $mod, undef, $ver);
        next if !$include_core    &&  $is_core;
        next if !$include_noncore && !$is_core;
        push @list, "$mod\t$ver\n";
    }

    App::lcpan::Cmd::ver_cmp_list::handle_cmd(%args, list=>join("", @list));
}

1;
# ABSTRACT:

=head1 SEE ALSO

L<App::cpanoutdated>
