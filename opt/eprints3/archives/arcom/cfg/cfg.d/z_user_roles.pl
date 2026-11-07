# Allow admins to destroy items (with notification), including once archived
push @{$c->{user_roles}->{admin}}, qw(
	+eprint/remove_with_email
	+eprint/remove_once_archived
);