const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Random = std.Random;
const Io = std.Io;

const heap = @import("structheap.zig");
const structs = @import("config.zig");

const Distribution = structs.Distribution;
const SimResults = structs.SimResults;
const SimConfig = structs.SimConfig;
const User = structs.User;

const Action = enum { nothing, like, reply, repost, quote };

pub const Event = struct {
    time: f64,          // when will the action be due
    type: Action,    // what will the user do
    id: u64,            // who does the action
};

const User = struct {
    .following: ArrayList(*User),  //neighbors
    .follower: ArrayList(*Users),
    .timeline: heap.Heap(*Post),
    .posts: ArrayList(*Post),
    .historic: ArrayList(*Post) = .empty,
    .policy: [5]f32,                        // as many as the number of actions
};

const Post = struct {
    .id: u64,
    .time: f64,
};

pub fn v1(config: SimConfig) void {
    
    var hp = heap.Heap(Event).init();
    defer hp.deinit(gpa);

    var processed_events: u64 = 0;
    var t_clock: f64 = 0.0;

    // add a first event per every user
    // create minheap (timeline) per user containing which is the next post the user has to see.
    // and append the first element of the event scheduling algorithm
    
    while (t_clock <= config.horizon and hp.len() > 0) : (processed_events += 1) {
        const next_event = hp.pop().?; // we use ? because we are absolutely sure there will be an element
        t_clock = next_event.time;

        switch (next_event.type) {
            Action.nothing => std.debug.print("Hothing!\n");
            Action.like => std.debug.print("Hothing!\n");
            Action.reply => std.debug.print("Update all the followers timelines!\n");
            Action.repost => std.debug.print("Update all the followers timelines!\n");
            Action.quote => std.debug.rpint("Update all the followers timelines!\n");
        } 
    }
}

pub fn eventSchedulingBus(gpa: Allocator, random: Random, config: SimConfig, traca_writer: ?*Io.Writer, user_writer: ?*Io.Writer) !SimResults {
    var hp = heap.Heap(Event).init();
    defer hp.deinit(gpa);

    var processed_events: u64 = 0;
    var t_clock: f64 = 0.0;

    // variables d'estat globals
    var num_passengers_queue: u64 = 0;
    var current_bus_capacity: u64 = 0;
    var lost_passengers: u64 = 0;
    var lost_buses: u64 = 0;
    var realized_bus_capacity: u64 = 0.0;

    var boarding_active: bool = false;

    // stats
    var area_queue: f64 = 0.0;
    var area_system: f64 = 0.0;
    var area_sq: f64 = 0.0;

    // accumulators for averages
    var sum_queue_time: f64 = 0.0;
    var sum_service_time: f64 = 0.0;
    var sum_total_time: f64 = 0.0;
    var total_served_passengers: u64 = 0;
    
    var last_event_time: f64 = 0.0;
    var event_id_counter: u64 = 0;

    // if a zero is passed, make it maxint
    const queue_max_capacity: u64 = if (config.system_capacity == 0) std.math.maxInt(@TypeOf(config.system_capacity)) else config.system_capacity;

    // primera arribada de passatjer per començar la simulació
    const t_p = try config.passenger_interarrival.sample(random);
    event_id_counter += 1;
    try hp.push(gpa, Event{ .time = t_p, .type = .arrival, .id = event_id_counter });

    // primera arribada de bus per començar la simulació
    const t_b = try config.bus_interarrival.sample(random);
    event_id_counter += 1;
    try hp.push(gpa, Event{ .time = t_b, .type = .service, .id = event_id_counter });

    var bus_stop: ArrayList(User) = .empty;
    defer bus_stop.deinit(gpa);
    var first_user_in_queue: usize = 0;

    var current_bus_arrival: f64 = 0.0;
    var acc_boarding: f64 = 0.0;
    
    // write the header
    if (user_writer) |writer| {
        try User.formatCsvHeader(writer);
    }

    while (t_clock <= config.horizon and hp.len() > 0) : (processed_events += 1) {
        const next_event = hp.pop().?; // we use ? because we are absolutely sure there will be an element
        t_clock = next_event.time;

        if (traca_writer) |writer| {
            try writer.print("Estat {d}: ({d},{d}); t={d:.4}\n", .{ processed_events, num_passengers_queue, current_bus_capacity, t_clock });
        }
        const deltat = t_clock - last_event_time;

        const people_on_bus = realized_bus_capacity - current_bus_capacity;
        const system_size = num_passengers_queue + people_on_bus;
        area_queue += @as(f64, @floatFromInt(num_passengers_queue)) * deltat; // n_j (t_j - t_i)
        area_system += @as(f64, @floatFromInt(system_size)) * deltat; // L
        area_sq += @as(f64, @floatFromInt(system_size * system_size)) * deltat; // n_j**2 (t_j - t_i)

        switch (next_event.type) {
            EventType.arrival => { // passanger arrives

                event_id_counter += 1;
                const time_passanger = try config.passenger_interarrival.sample(random);
                const next_time = t_clock + time_passanger;

                try hp.push(gpa, Event{
                    .time = next_time,
                    .type = .arrival, //hostia que guapo
                    .id = event_id_counter,
                });

                // if the sistem is full, client is lost
                if (num_passengers_queue >= queue_max_capacity) {
                    lost_passengers += 1;
                } else {
                    num_passengers_queue += 1; //len de passangers_in_queue
                    try bus_stop.append(gpa, User{ .id = processed_events, .arrival = t_clock });
                }
            },
            EventType.service => { // bus arrives
                // si ja hi ha un bus a la parada, poso la memòria a zero
                const time_bus = try config.bus_interarrival.sample(random);

                if (boarding_active) {
                    lost_buses += 1;
                    event_id_counter += 1;
                    try hp.push(gpa, Event{ .time = t_clock + time_bus, .type = .service, .id = event_id_counter });
                } else {
                    // com que no hi ha cap bus, genero la capacitat d'aquest
                    current_bus_arrival = t_clock;
                    realized_bus_capacity = try config.bus_capacity.sampleInt(random);
                    try hp.push(gpa, Event{ .time = t_clock + time_bus, .type = .service, .id = event_id_counter });

                    current_bus_capacity = realized_bus_capacity;

                    event_id_counter += 1;

                    // if we are NOT boarding start the boarding
                    if (num_passengers_queue > 0 and current_bus_capacity > 0 and boarding_active == false) {
                        const duration = try config.boarding_time.sample(random);

                        try hp.push(gpa, Event{ .time = t_clock + duration, .type = .boarding, .id = event_id_counter });

                        (&bus_stop.items[first_user_in_queue]).*.boarding_time = duration;
                        boarding_active = true;
                    }
                }
            },
            EventType.boarding => { // passatjer ha pujat a l'autobus
                if (num_passengers_queue > 0 and current_bus_capacity > 0) {
                    // update leaving time of the queue
                    const leaving_user: *User = &bus_stop.items[first_user_in_queue];
                    leaving_user.*.about_to_board = current_bus_arrival + acc_boarding;
                    leaving_user.*.boarded = leaving_user.*.about_to_board.? + leaving_user.*.boarding_time.?;
                    acc_boarding += leaving_user.*.boarding_time.?;

                    leaving_user.*.queue_time = leaving_user.*.about_to_board.? - leaving_user.*.arrival;
                    leaving_user.*.enqueued_time = leaving_user.*.queue_time.? + leaving_user.*.boarding_time.?;

                    first_user_in_queue += 1;

                    num_passengers_queue -= 1;
                    current_bus_capacity -= 1;

                    // si encara hi ha passatjers a la marquesina i el bus no és ple
                    if (num_passengers_queue > 0 and current_bus_capacity > 0) {
                        event_id_counter += 1;
                        const duration = try config.boarding_time.sample(random);

                        try hp.push(gpa, Event{ .time = t_clock + duration, .type = .boarding, .id = event_id_counter });

                        (&bus_stop.items[first_user_in_queue]).*.boarding_time = duration;
                    } else {
                        boarding_active = false; //stop the boearding once there is no passnegers or the bus is full

                        const passengers_on_bus = realized_bus_capacity - current_bus_capacity;
                        const start_index: usize = first_user_in_queue - passengers_on_bus;

                        for (start_index..first_user_in_queue) |i| {
                            const user: *User = &bus_stop.items[i];
                            user.*.departure = t_clock;
                            user.*.service_time = (t_clock - user.*.about_to_board.?);
                            user.*.total_time = user.*.queue_time.? + user.*.service_time.?;
                            
                            // update accumulators
                            sum_queue_time += user.*.queue_time.?;
                            sum_service_time += user.*.service_time.?;
                            sum_total_time += user.*.total_time.?;
                            total_served_passengers += 1;

                            if (user_writer) |writer| {
                                try user.*.formatCsv(writer);
                            }
                        }

                        if (first_user_in_queue > 0) {
                           bus_stop.replaceRange(gpa, 0, first_user_in_queue, &[_]User{}) catch unreachable;
                           first_user_in_queue = 0;
                        }

                        acc_boarding = 0.0;
                        current_bus_capacity = 0;
                        realized_bus_capacity = 0;
                    }
                }
            },
        }

        last_event_time = t_clock;
    }

    if (traca_writer) |writer| {
        try writer.flush(); // Don't forget to flush! :)
    }

    if (user_writer) |writer| {
        try writer.flush();
    }

    const L = area_system / t_clock;
    const f_served = if (total_served_passengers > 0) @as(f64, @floatFromInt(total_served_passengers)) else 1.0;

    return SimResults{
        .average_clients = area_system / t_clock,
        .variance = (area_sq / t_clock) - L * L,
        .duration = t_clock,
        .lost_passengers = lost_passengers,
        .lost_buses = lost_buses,
        .processed_events = processed_events,
        .average_queue_clients = area_queue / t_clock,
        .average_queue_time = sum_queue_time / f_served,
        .average_service_time = sum_service_time / f_served,
        .average_total_time = sum_total_time / f_served,
    };
}


