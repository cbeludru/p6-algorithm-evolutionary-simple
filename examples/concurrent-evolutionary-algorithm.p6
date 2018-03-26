#!/usr/bin/env perl6

use v6;

use Algorithm::Evolutionary::Simple;
constant tournament-size = 4;

sub regular-EA ( UInt :$length = 64,
		 UInt :$population-size = 256,
		 UInt :$diversify-size = 8,
		 UInt :$max-evaluations = 10000, ) {
    
    my Channel $raw .= new;
    my Channel $evaluated .= new;
    my Channel $channel-three = $evaluated.Supply.batch( elems => tournament-size).Channel;
    my Channel $shuffler = $raw.Supply.batch( elems => $diversify-size).Channel;
    my Channel $output .= new;
    
    $raw.send( random-chromosome($length).list ) for ^$population-size;
    
    my $count = 0;
    my $end;
    
    my $shuffle = start react whenever $shuffler -> @group {
	my @shuffled = @group.pick(*);
	$raw.send( $_ ) for @shuffled;
    }
    
    my $evaluation = start react whenever $raw -> $one {
	my $with-fitness = $one => max-ones($one);
	$output.send( $with-fitness );
	$evaluated.send( $with-fitness);
	say $count++, " → $with-fitness";
	if $with-fitness.value == $length {
	    $raw.close;
	    $end = "Found" => $count;
	}
	if $count >= $max-evaluations {
	    $raw.close;
	    $end = "Found" => False;
	}
    }
    
    my $selection = start react whenever $channel-three -> @tournament {
	my @ranked = @tournament.sort( { .values } ).reverse;
	$evaluated.send( $_ ) for @ranked[0..1];
	my @crossed = crossover(@ranked[0].key,@ranked[1].key);
	$raw.send( $_.list ) for @crossed.map: { mutation($^þ)};
    }
    
    await $evaluation;
    
    loop {
	if my $item = $output.poll {
	    $item.say;
	} else {
	    $output.close;
	}
	if $output.closed  { last };
    }
}

sub MAIN ( UInt :$repetitions = 30,
           UInt :$length = 64,
	   UInt :$population-size = 256,
	   UInt :$diversify-size = 8,
	   UInt :$max-evaluations = 10000 ) {

    my @found;
    for ^$repetitions {
	my $result = regular-EA( length => $length,
				 population-size => $population-size,
				 diversify-size => $diversify-size,
				 max-evaluations => $max-evaluations );
	
	@found.push( $result );
    }
    say "Result ", @found;

}
