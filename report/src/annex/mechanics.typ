This annex talks about which mechanics have been implemented and discarded though a non explanation of the model. 

== Quoting

A user can decide to quote a post, establishing a new piece of content that directly references a `parent_id`. 
- The newly generated quote post is immediately marked as seen by its creator and is propagated to their followers.
- Quoting is strictly a reactive action; unlike standard post generation, creating a quote does not automatically schedule subsequent post creations in the queue.
- To ensure coherent interaction flow, whenever a follower encounters a quote post in their timeline, the system automatically retrieves the original parent post and injects it at the exact same timestamp. This ensures the user has full context before responding.

The idea was to extend the cascades with a comment over it. Without content aware posts, this did not seem worth to add complexity with diminishing results.

== Notifications

Every quote actively generates a targeted notification aimed at the original author, breaking the strictly linear consumption of the timeline:
- If the target user is online when the notification arrives, the system bypasses normal propagation and immediately drops the new quote post directly into the user's active timeline to be processed next.
- If the user is offline, the system evaluates an `attend_offline_notification` probability. Upon success, the user abruptly "wakes up" out of schedule; the quote is injected into their timeline, and a new action event is dispatched to simulate the user logging on specifically to check the interaction.
- If the offline user fails the probability check, the notification lands in a Pending Buffer. Once the user finally comes back online, they are forced to process and empty this priority buffer before returning to standard timeline consumption.

This mechanics attempted at breaking the stiffness of sessions, as real life probably contains smaller and few interactions that the sampling sessions method discards by definition.

== Replies

Never implemented due to their complexity, and discarded with a very similar argument to quoting. Without content aware posts it's very difficult to justify the added complexity for the diminishing results that this will provide.
