#!/usr/bin/env perl
use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Compare qw{is};

our %defs;

InternalTimer(time()+1, sub {
	my $target = shift;
	my $targetHash = $defs{$target};
    plan(12);
    my $rmsg="MS;P1=502;P2=-9212;P3=-1939;P4=-3669;D=1234;CP=1;SP=2;";
    my %signal_parts=SIGNALduino_Split_Message($rmsg,$targetHash->{NAME});

    is( $signal_parts{messagetype}, "MS", "SIGNALduino_Split_Message check MS messagetype" );
    is( $signal_parts{rawData}, "1234", "SIGNALduino_Split_Message check MS rawData" );
    is( $signal_parts{syncidx}, "2", "SIGNALduino_Split_Message check MS syncIdx" );
    is( $signal_parts{clockidx}, "1", "SIGNALduino_Split_Message check MS clockIdx" );
    is( $signal_parts{pattern}{1}, "502", "SIGNALduino_Split_Message check MS pattern 1" );

    $rmsg="MU;P1=502;P2=-9212;P3=-1939;P4=-3669;D=1234;CP=1;";
    %signal_parts=SIGNALduino_Split_Message($rmsg,$targetHash->{NAME});
    is( $signal_parts{messagetype}, "MU", "SIGNALduino_Split_Message check MU messagetype" );
    is( $signal_parts{rawData}, "1234", "SIGNALduino_Split_Message check MU rawData" );
    is( $signal_parts{pattern}{1}, "502", "SIGNALduino_Split_Message check MU pattern 1");

    $rmsg="MC;LL=-1074;LH=889;SL=-599;SH=368;D=55AB;C=488;L=168;R=246;";
    %signal_parts=SIGNALduino_Split_Message($rmsg,$targetHash->{NAME});
    is( $signal_parts{messagetype}, "MC", "SIGNALduino_Split_Message check MC messagetype" );
    is( $signal_parts{rawData}, "55AB", "SIGNALduino_Split_Message check MC rawData" );
    is( $signal_parts{pattern}{LH}, "889", "SIGNALduino_Split_Message check MC pattern LH" );
    is( $signal_parts{pattern}{SL}, "-599", "SIGNALduino_Split_Message check MC pattern SH" );

	exit(0);
},'dummyDuino');

1;