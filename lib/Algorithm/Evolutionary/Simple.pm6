use v6.c;

unit module Algorithm::Evolutionary::Simple:ver<0.0.5>;

sub random-chromosome( UInt $length --> List(Seq) ) is export {
    return Bool.pick() xx $length;
}

sub initialize( UInt :$size,
		UInt :$genome-length --> Array ) is export {
    my @initial-population;
    for 1..$size -> $p {
	@initial-population.push: random-chromosome( $genome-length );
    }
    return @initial-population;
}

sub max-ones( @chromosome --> Int ) is export is pure {
    return @chromosome.map( *.so).sum;
}

sub royal-road( @chromosome --> Int ) is export is pure {
    return @chromosome.rotor(4).grep( so (*.all == True|False) ).elems;
}

proto evaluate( :@population,
	        :%fitness-of,
	        :$evaluator,
                |) { * };

multi sub evaluate( :@population,
	            :%fitness-of,
	            :$evaluator --> Mix ) is export {
    my MixHash $pop-bag;
    for @population -> $p {
	if  ! %fitness-of{$p}.defined {
	    %fitness-of{$p} = $evaluator( $p );

	}
	$pop-bag{$p} = %fitness-of{$p};
    }
    return $pop-bag.Mix;
}

multi sub evaluate( :@population,
	            :%fitness-of,
	            :$evaluator,
                    Bool :$auto-t --> Mix ) is export {
    my @unique-population = @population.unique;
    my @evaluations = @unique-population.race(degree => 8).map( { $^p => $evaluator( $^p ) } );
    my MixHash $pop-bag;
    for @evaluations -> $pair {
        $pop-bag{$pair.key.item} = $pair.value;
    }
    return $pop-bag.Mix;
}

sub get-pool-roulette-wheel( Mix $population,
			     UInt $need = $population.elems ) is export {
    return $population.roll: $need;
}

sub mutation ( @chromosome is copy --> List ) is export {
    my $pick = (^@chromosome.elems).pick;
    @chromosome[ $pick ] = !@chromosome[ $pick ];
    return @chromosome;
}

sub crossover ( @chromosome1 is copy,
		@chromosome2 is copy )
                returns List
                is export {
    my $length = @chromosome1.elems;
    my $xover1 = (^($length-2)).pick;
    my $xover2 = ($xover1^..^$length).pick;
    my @x-chromosome = @chromosome2;
    my @þone = $xover1..$xover2;
    @chromosome2[@þone] = @chromosome1[@þone];
    @chromosome1[@þone] = @x-chromosome[@þone];
    return [@chromosome1,@chromosome2];
}

sub produce-offspring( @pool,
		       $size = @pool.elems --> Seq ) is export {
    my @new-population;
    for 1..($size/2) {
	my @χx = @pool.pick: 2;
	@new-population.push: crossover(@χx[0], @χx[1]).Slip;
    }
    return @new-population.map( { mutation( $^þ ) } );

}

sub best-fitness(Mix $population ) is export is pure {
    return $population.sort(*.value).reverse.[0].value;
}

proto sub generation(Mix :$population,
	             :%fitness-of,
	             :$evaluator,
	             :$population-size,
                     | --> Mix ) { * };

multi sub generation(Mix :$population,
	       :%fitness-of,
	       :$evaluator,
	       :$population-size = $population.elems --> Mix ) is export {

    my $best = $population.sort(*.value).reverse.[0..1].Mix; # Keep the best as elite
    my @pool = get-pool-roulette-wheel( $population, $population-size-2);
    my @new-population= produce-offspring( @pool, $population-size );
    return Mix(evaluate( population => @new-population,
			 fitness-of => %fitness-of,
			 evaluator => $evaluator ) ∪ $best );
}

multi sub generation(Mix :$population,
	       :%fitness-of,
	       :$evaluator,
	       :$population-size = $population.elems,
               Bool :$auto-t --> Mix ) is export {

    my $best = $population.sort(*.value).reverse.[0..1].Mix; # Keep the best as elite
    my @pool = get-pool-roulette-wheel( $population, $population-size-2);
    my @new-population= produce-offspring( @pool, $population-size );
    return Mix(evaluate( population => @new-population,
			 fitness-of => %fitness-of,
			 evaluator => $evaluator,
                         :$auto-t ) ∪ $best );
}

sub mix( $population1, $population2, $size --> Mix ) is export {
    my $new-population = $population1 ∪ $population2;
    return $new-population.sort(*.value).reverse.[0..($size-1)].Mix;
}

=begin pod

=head1 NAME

Algorithm::Evolutionary::Simple - A simple evolutionary algorithm

=head1 SYNOPSIS

  use Algorithm::Evolutionary::Simple;

=head1 DESCRIPTION

Algorithm::Evolutionary::Simple is a module for writing simple and
quasi-canonical evolutionary algorithms in Perl 6. It uses binary
representation, integer fitness (which is needed for the kind of data
structure we are using) and a single fitness function.

It is intended mainly for demo purposes. In the future,
more versions will be available.			

It uses a fitness cache for storing and not reevaluating,
so take care of memory bloat.
   
=head1 METHODS

=head2 initialize( UInt :$size,
		   UInt :$genome-length --> Array ) is export

Creates the initial population of binary chromosomes with the indicated length; returns an array. 

=head2 random-chromosome(  UInt $length --> List )

Generates a random chromosome of indicated length. Returns a C<Seq> of C<Bool>s

=head2 max-ones( @chromosome --> Int )

Returns the number of trues (or ones) in the chromosome.

=head2 royal-road( @chromosome )

That's a bumpy road, returns 1 for each block of 4 which has the same true or false value.

=head2 multi evaluate( :@population,
		       :%fitness-of,
		       :$evaluator,
                       :$auto-t = False --> Mix ) is export

Evaluates the chromosomes, storing values in the fitness cache. If C<auto-t> is set to 'True', uses autothreading for faster operation (if needed). In absence of that parameter, defaults to sequential.

=head2 get-pool-roulette-wheel( Mix $population,
				UInt $need = $population.elems ) is export

Returns C<$need> elements with probability proportional to its I<weight>, which is fitness in this case.

=head2 mutation( @chromosome is copy --> Array )

Returns the chromosome with a random bit flipped.

=head2 crossover ( @chromosome1 is copy, @chromosome2 is copy ) returns List

Returns two chromosomes, with parts of it crossed over. Generally you will want to do crossover first, then mutation. 

=head2 produce-offspring( @pool,
		          $size = @pool.elems --> Seq ) is export

Produces offspring from an array that contains the reproductive pool; it returns a C<Seq>.

=head2 best-fitness( $population )

Returns the fitness of the first element. Mainly useful to check if the algorithm is finished.

=head2 multi sub generation(  :@population,
		              :%fitness-of,
		              :$evaluator,
	                      :$population-size = $population.elems,
                              Bool :$auto-t --> Mix )

Single generation of an evolutionary algorithm. The initial C<Mix>
has to be evaluated before entering here using the C<evaluate> function. Will use auto-threading if C<$auto-t> is C<True>.

=head2 mix( $population1, $population2, $size --> Mix ) is export 
  
Mixes the two populations, returning a single one of the indicated size


=head1 SEE ALSO

There is a very interesting implementation of an evolutionary algorithm in L<Algorithm::Genetic>. Check it out.

This is also a port of L<Algorithm::Evolutionary::Simple to Perl6|https://metacpan.org/release/Algorithm-Evolutionary-Simple>, which has a few more goodies. 

=head1 AUTHOR

JJ Merelo <jjmerelo@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2018 JJ Merelo

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
