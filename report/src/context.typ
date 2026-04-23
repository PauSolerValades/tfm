This section introduces context to the project: what a microblogging social network is, the nature of the phenomenon we want to study, and why Bluesky is the chosen social network to simulate.

== What is a Microblogging Social Network
<sec-context-definition>

Despite social networks being a relatively new addition to normal modern life, they have fundamentally changed how information is consumed and spread in the modern age. To adequately understand the aims of this project, some definitions and context regarding social networks are provided.

*Definition:* A *Social Network* is a structure made up of a set of actors (such as individuals or organizations) and the dyadic ties (interactions or relationships) between them. In a digital context, it is a platform that enables users to communicate, share information, and form communities.

This project tackles a very specific kind of social network: the microblogging network.

*Definition:* A *Microblogging Social Network* (e.g., Twitter/$bb(X)$ or Bluesky) is a specialized type of social network where users publish and exchange short-form content. This is enforced by a limit on the maximum number of characters per entry, known as microblogs or posts. A post, while traditionally text-based, can also include up to four multimedia elements.

[TODO: buscar sources per aquestes dues definitions]

To model a microblogging social network, it is imperative to understand and describe all the features that compose the application. Specifically, the following description is of the microblogging platform Bluesky (TODO: Cite bluesky), as it is the platform chosen to simulate (see @sec-context-bluesky).

The post is the fundamental building block of Bluesky, acting as the primary vehicle for the information that will be spread. A user sees these posts in a feed, which is a sorted collection of posts categorized by specific rules. For the feed to contain posts, we must explain the other fundamental relationship in a social network: the follow.

[TODO: Picture of the feed of Bluesky]

A user can follow other users, allowing the content of those users to appear to the "follower". That is, if user $u$ follows user $v$, all the posts that user $v$ creates will appear in the feed of user $u$. This is one mechanism for a user's feed to populate with posts. The other way for content to travel is how a user interacts with a post once it appears in their feed, this being the main source of post appearance in the user feed. Conversely, there are some actions a user can perform over other users which limit the posts that can appear on a user's feed: a user can block (preventing both users from seeing each other's activity) or mute (activity of a muted user is not shown to the user) another user, which will alter the posts that can appear on the timeline of the user who performed that action.

A user can meaningfully act on a post in four different ways:
- *Repost:* If user $u$ reposts a post in their feed, that post will subsequently appear in the feeds of user $u$'s followers.
- *Like:* If a user likes a post, it won't show in their followers' feeds, but it will be stored in the user's profile (discussed later).
- *Quote:* This is a direct answer attached to a post. It is shown together with the original post in the followers' timeline, acting as commentary on the original content.
- *Reply:* This is a direct response to an original post. The reply will be shown in the followers' feed and clearly marked as a reply, though the original post usually won't be shown alongside it unless the follower also follows the original author.

[TODO: Show pictures of how a quote is shown, how a reply is shown]

Lastly, every user has a profile, which is customizable with a profile picture, a description, and a background image. The profile acts as a public ledger containing all posts the user has written or reposted, all replies made to other posts, and all likes given.

Bluesky, as an open platform, allows for user-made feeds with diverse rules and categories dictating which posts are shown. These include feeds focused on highly specific topics (such as technology, local events, or art). The two primary feeds provided by default are the _Discover_ feed and the _Following_ feed.

The Discover feed uses a recommendation algorithm to suggest the most relevant posts to a user based on their tastes and the network of people they follow. This criterion usually excludes the temporal component of when posts were created or reposted, focusing instead on content similarity and engagement.

The Following feed is a traditional social network timeline. It displays creations and reposts exclusively from the accounts the user follows, showing them in strict reverse-chronological order, from newest to oldest.


[TODO: Picture of the tabs showing the different feeds the Bluesky app has]== Model


== Why Bluesky?
<sec-context-bluesky>

TBD: Bluesky is open, talk about ATProto, and talk about how the firehose works to obtain the data

Bluesky is ...

== Problem Description

The problems with social networks are bla bla and I did all of this to try to solve them.
