# Unit 3 finding: the "not spam" count is wrong

To the dashboard team,

The dashboard says 22 of our 200 ratings are not spam. The real number is 188. Only 12 ratings were ever taken down for spam. The other 188 are either normal ratings that were never removed (166 of them) or ratings removed for some other reason, like duplicates or a user asking for it to be deleted (22). The dashboard only picked up that last group of 22 and missed every normal rating.

The problem is the "reason for removal" field. It only gets filled in when a rating is taken down, so for the 166 normal ratings it is empty. When the dashboard asks for ratings where the reason is "not spam", the database doesn't treat an empty field as "not spam". It treats it as unknown and drops the rating from the count. There's no error message, so nobody noticed. You can see the gap if you add things up: the dashboard's numbers (22 not spam plus 12 spam) only cover 34 ratings, while the corrected numbers (188 plus 12) cover all 200.

The frozen payout should stay frozen until it's recalculated with 188 instead of 22. The dashboard also needs to be changed so that ratings with an empty removal reason are counted as not spam. It would be worth having someone check the new number against the raw data before the payout goes out, and looking at any other dashboard numbers that use the same field, since they could be off for the same reason.
