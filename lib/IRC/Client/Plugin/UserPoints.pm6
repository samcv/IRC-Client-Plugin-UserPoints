use v6;

use IRC::Client;
use PerlStore::FileStore;

class IRC::Client::Plugin::UserPoints {

	has Str $.db-file-name
		is readonly
		= 'userPoints.txt';

	# Load the hash from $db-file-name if it is readable and writable
	# TODO Check &from-file returns
	has %!user-points
		=  ( $!db-file-name.IO.r && $!db-file-name.IO.w )
			?? from_file( $!db-file-name )
			!! Hash.new;

	has Str $.command-prefix
		is readonly
		where .chars > 0 && .chars <=1
		= '!';

	has Int $.target-points where * > 0 = 42;

	# TODO Overflow check : -1 point if overflow
	# TODO Reduce message because spamming
	# TODO Save the current channel when adding a point
	multi method irc-all( $e where /^ (\w+) ([\+\+ | \-\-]) [\s+ (\w+) ]? $/ ) {
		my $user-name = $0;
		my $operation = $1;
		my $category = $2
			?? $2
			!! 'main';

		# Check if $user-name is different from message sender
		return "Influencing points of himself is not possible."
			if $e.nick() ~~ $user-name;

		my $operation-name = '';

		given $operation {
			when '++' {
				%!user-points{$user-name}{$category} += 1 when '++';
				$operation-name = 'Adding';
			}
			when '--' {
				%!user-points{$user-name}{$category} -= 1 when '--';
				$operation-name = 'Removing';
			}
		}

		# Remove user's category if it reaches 0
		%!user-points{$user-name}{$category}:delete
			unless %!user-points{$user-name}{$category};

		# Remove user if he has no categories
		%!user-points{$user-name}:delete
			unless %!user-points{$user-name};

		# Save scores
		to_file( $!db-file-name, %!user-points );

		return %!user-points{$user-name}{$category} == $!target-points
			?? "Congratulations, $user-name reached $!target-points in $category!"
			!! "$operation-name one point to $user-name in « $category » category";
	}

	# TODO Total for !scores
	# TODO Detailed for !scores <nick>
	multi method irc-all( $e where { my $p = $!command-prefix; $e ~~ /^ $p "scores" / } ) {
		unless keys %!user-points {
			return "No attributed points, yet!"
		}

		for keys %!user-points -> $user-name {
			my @rep;
			for %!user-points{$user-name} -> %cat {
				for kv %cat -> $k, $v {
					push @rep, "$v for $k";
				}
			}
			$e.reply: "« $user-name » has some points : { join( ', ', @rep ) }";
		}
	}
}
