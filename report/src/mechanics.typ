
*Quoting*
A user can decide to quote a post, establishing a new piece of content that directly references a `parent_id`. 
- The newly generated quote post is immediately marked as seen by its creator and is propagated to their followers.
- Quoting is strictly a reactive action; unlike standard post generation, creating a quote does not automatically schedule subsequent post creations in the queue.
- To ensure coherent interaction flow, whenever a follower encounters a quote post in their timeline, the system automatically retrieves the original parent post and injects it at the exact same timestamp. This ensures the user has full context before responding.

*Notifications*
Every quote actively generates a targeted notification aimed at the original author, breaking the strictly linear consumption of the timeline:
- If the target user is online when the notification arrives, the system bypasses normal propagation and immediately drops the new quote post directly into the user's active timeline to be processed next.
- If the user is offline, the system evaluates an `attend_offline_notification` probability. Upon success, the user abruptly "wakes up" out of schedule; the quote is injected into their timeline, and a new action event is dispatched to simulate the user logging on specifically to check the interaction.
- If the offline user fails the probability check, the notification lands in a Pending Buffer. Once the user finally comes back online, they are forced to process and empty this priority buffer before returning to standard timeline consumption.

To maintain realism as a discrete event model, user stamina mechanics can be introduced: if a user logs in to a massive backlog of notifications, they might only process a subset (e.g., following a Geometric distribution) before getting bored and discarding the rest.

