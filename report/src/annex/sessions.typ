#import "../utils.typ": *

This appendix serves as the sessions extra information.

== Current Sessions Validity
<apx-sessions-def>

Despite the utility of the Bluesky Firehose, it is definetly not the best dataset for figuring out what a meaningfull section is.

Firehose #todo[check appropiately] is an event register of all the information that updates the state of the user regarding the platform ---in more techincal terms, that it updates the database. From this information we have data points that confim us that the user is online, as it has interacted with the platform at the time of the event.

Lets now define the most specific type of session we would be interested in obtaining to highligh the limitations of the Firehose for the ideal data, as well as proposing an experiment to obtain real data from the users using the Bluesky current features and funcitonalities.

#def(name: "Interaction Session")[
  An Interactive Session is the time the user has been online (connected to the platform) and checking _any_ type of content feed.
]

For this work is not rellevant if the user has been updating its profile, or messaging another user: the important information is for how long did the user see posts, how many posts did the user not interact with, and which ones did he interact with. This project works with the underlying ---and now made explicit--- assumption that the meaningful session interval is a subset of the session defined in the calibraion section, despite being not true to the maximum extent:
- If a user connect, checks the timeline for 3 minutes but does not interact with any post.
- If a user just check the feed, we just know the session from the first meaningful (like, repost or reply) with the first post. If that user has been some time checking but not liking, out sessions will be shorter (consistently biased) than the real counterpart.

For the puroposes of this work, the meaningfull sessions are considered to be equivalent as the normal sessions due to two factos:
- *Availability*: The firehose is the data available at the time.
- *Similiariy*: As consuming content from feeds is the main feature of the social network, it is reasonable to assume that users will be the majority of time checking those feeds. Therefore, we treat them to be the same and just as consuming feeds and content as an approximation.


== Alternative Methodologies Attempted
<apx-sessions-method>

There is literature regarind ways to properly define session, and it does not converge to a unique method nor a unique defintion. #todo[check this claim]

To define the sessions, three ways have been considered:
- Predefined session: define the minimum gap between two sessions and consider them appart. This is the usual route that marketing and social networks take.
- Clusteing: use a clustering algorithm that follows a strategy to obtain the sessions directly.

For the nature of this project, the predefined session length is been discarded from the beginning.

=== Tukey's Fence

.

== Obtaining a Better Dataset
<apx-sessions-dataset>

Explain that if you create a better appview, you can get information from everything, and the second next thing (and more feasible) is to create a feed that is served by you, therfore you will know exactly what's happening there.
