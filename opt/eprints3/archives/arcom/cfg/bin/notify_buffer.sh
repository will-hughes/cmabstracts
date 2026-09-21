#!/bin/bash

ADMINEMAIL="admin@cmabstracts.com"

COUNT=$(mysql arcom -se \
  "SELECT COUNT(*) FROM eprint WHERE eprint_status='buffer';" 2>/dev/null)

if [ "$COUNT" -gt 0 ]; then
  echo -e "There are $COUNT item(s) awaiting review in the CM Abstracts buffer.\n\nReview them at: https://cmabstracts.com/cgi/users/home?screen=Review" \
  | mail -s "CM Abstracts: items awaiting review" $ADMINEMAIL
fi

