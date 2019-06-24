/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2019 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;
using TaskletSystem;
using Netsukuku.Neighborhood;
using Netsukuku.Identities;

namespace Netsukuku
{
    string json_string_object(Object obj)
    {
        Json.Node n = Json.gobject_serialize(obj);
        Json.Generator g = new Json.Generator();
        g.root = n;
        string ret = g.to_data(null);
        return ret;
    }

    string topology;
    string firstaddr;
    int pid;
    [CCode (array_length = false, array_null_terminated = true)]
    string[] interfaces;
    [CCode (array_length = false, array_null_terminated = true)]
    string[] _tasks;

    ITasklet tasklet;
    Commander cm;
    FakeCommandDispatcher fake_cm;
    NeighborhoodManager? neighborhood_mgr;
    IdentityManager? identity_mgr;
    HashMap<string,HandledNic> handlednic_map;
    HashMap<int,NodeArc> arc_map;
    SkeletonFactory skeleton_factory;
    StubFactory stub_factory;
    HashMap<string,PseudoNetworkInterface> pseudonic_map;
    ArrayList<NodeID> my_nodeid_list;
    ArrayList<string> tester_events;

    int main(string[] _args)
    {
        pid = 0; // default
        OptionContext oc = new OptionContext("<options>");
        OptionEntry[] entries = new OptionEntry[4];
        int index = 0;
        entries[index++] = {"pid", 'p', 0, OptionArg.INT, ref pid, "Fake PID (e.g. -p 1234).", null};
        entries[index++] = {"interfaces", 'i', 0, OptionArg.STRING_ARRAY, ref interfaces, "Interface (e.g. -i eth1). You can use it multiple times.", null};
        entries[index++] = {"tasks", 't', 0, OptionArg.STRING_ARRAY, ref _tasks, "Tasks (e.g. -t dothis,2,blabla). You can use it multiple times.", null};
        entries[index++] = { null };
        oc.add_main_entries(entries, null);
        try {
            oc.parse(ref _args);
        }
        catch (OptionError e) {
            print(@"Error parsing options: $(e.message)\n");
            return 1;
        }

        ArrayList<string> args = new ArrayList<string>.wrap(_args);

        tester_events = new ArrayList<string>();
        ArrayList<string> devs;
        // Names of the network interfaces to monitor.
        devs = new ArrayList<string>();
        foreach (string dev in interfaces) devs.add(dev);

        ArrayList<string> tasks = new ArrayList<string>();
        foreach (string task in _tasks) tasks.add(task);

        if (pid == 0) error("Bad usage");
        if (devs.is_empty) error("Bad usage");

        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();
        fake_cm = new FakeCommandDispatcher();

        // Initialize modules that have remotable methods (serializable classes need to be registered).
        NeighborhoodManager.init(tasklet);
        IdentityManager.init(tasklet);
        typeof(WholeNodeSourceID).class_peek();
        typeof(WholeNodeUnicastID).class_peek();
        typeof(EveryWholeNodeBroadcastID).class_peek();
        typeof(NeighbourSrcNic).class_peek();

        // Initialize pseudo-random number generators.
        string _seed = @"$(pid)";
        uint32 seed_prn = (uint32)_seed.hash();
        PRNGen.init_rngen(null, seed_prn);
        NeighborhoodManager.init_rngen(null, seed_prn);
        IdentityManager.init_rngen(null, seed_prn);

        // Pass tasklet system to the RPC library (ntkdrpc)
        init_tasklet_system(tasklet);

        // Commander
        cm = Commander.get_singleton();

        // RPC
        skeleton_factory = new SkeletonFactory();
        stub_factory = new StubFactory();

        int bid = fake_cm.begin_block();
        fake_cm.single_command_in_block(bid, new ArrayList<string>.wrap({
            @"sysctl", @"net.ipv4.ip_forward=1"}));
        fake_cm.single_command_in_block(bid, new ArrayList<string>.wrap({
            @"sysctl", @"net.ipv4.conf.all.rp_filter=0"}));
        fake_cm.end_block(bid);

        // Init module Neighborhood
        neighborhood_mgr = new NeighborhoodManager(
            1000 /*very high max_arcs*/,
            new NeighborhoodStubFactory(),
            new NeighborhoodQueryCallerInfo(),
            new NeighborhoodIPRouteManager(),
            () => @"169.254.$(PRNGen.int_range(0, 255)).$(PRNGen.int_range(0, 255))");
        skeleton_factory.whole_node_id = neighborhood_mgr.get_my_neighborhood_id();
        // connect signals
        neighborhood_mgr.nic_address_set.connect(neighborhood_nic_address_set);
        neighborhood_mgr.arc_added.connect(neighborhood_arc_added);
        neighborhood_mgr.arc_changed.connect(neighborhood_arc_changed);
        neighborhood_mgr.arc_removing.connect(neighborhood_arc_removing);
        neighborhood_mgr.arc_removed.connect(neighborhood_arc_removed);
        neighborhood_mgr.nic_address_unset.connect(neighborhood_nic_address_unset);

        handlednic_map = new HashMap<string,HandledNic>();
        pseudonic_map = new HashMap<string,PseudoNetworkInterface>();
        Gee.List<string> if_list_dev = new ArrayList<string>();
        Gee.List<string> if_list_mac = new ArrayList<string>();
        Gee.List<string> if_list_linklocal = new ArrayList<string>();
        foreach (string dev in devs)
        {
            assert(!(dev in pseudonic_map.keys));
            string listen_pathname = @"recv_$(pid)_$(dev)";
            string send_pathname = @"send_$(pid)_$(dev)";
            string mac = @"fe:aa:aa:$(PRNGen.int_range(10, 99)):$(PRNGen.int_range(10, 99)):$(PRNGen.int_range(10, 99))";
            print(@"INFO: mac for $(pid),$(dev) is $(mac).\n");
            PseudoNetworkInterface pseudonic = new PseudoNetworkInterface(dev, listen_pathname, send_pathname, mac);
            pseudonic_map[dev] = pseudonic;

            // Set up NIC
            bid = fake_cm.begin_block();
            fake_cm.single_command_in_block(bid, new ArrayList<string>.wrap({
                @"sysctl", @"net.ipv4.conf.$(dev).rp_filter=0"}));
            fake_cm.single_command_in_block(bid, new ArrayList<string>.wrap({
                @"sysctl", @"net.ipv4.conf.$(dev).arp_ignore=1"}));
            fake_cm.single_command_in_block(bid, new ArrayList<string>.wrap({
                @"sysctl", @"net.ipv4.conf.$(dev).arp_announce=2"}));
            fake_cm.single_command_in_block(bid, new ArrayList<string>.wrap({
                @"ip", @"link", @"set", @"dev", @"$(dev)", @"up"}));
            fake_cm.end_block(bid);

            // Start listen datagram on dev
            skeleton_factory.start_datagram_system_listen(listen_pathname, send_pathname, new NeighbourSrcNic(mac));
            print(@"started datagram_system_listen $(listen_pathname) $(send_pathname) $(mac).\n");
            // Run monitor. This will also set the IP link-local address,
            //  the stream_listener will start and the 'linklocal' field will be compiled.
            neighborhood_mgr.start_monitor(pseudonic_map[dev].nic);
            tasklet.ms_wait(5);
            print(@"INFO: linklocal for $(mac) is $(handlednic_map[dev].linklocal).\n");

            if_list_dev.add(dev);
            if_list_mac.add(mac);
            if_list_linklocal.add(handlednic_map[dev].linklocal);
        }

        arc_map = new HashMap<int,NodeArc>();
        my_nodeid_list = new ArrayList<NodeID>();

        // Init module Identities
        identity_mgr = new IdentityManager(
            if_list_dev, if_list_mac, if_list_linklocal,
            new IdmgmtNetnsManager(),
            new IdmgmtStubFactory(),
            () => @"169.254.$(PRNGen.int_range(0, 255)).$(PRNGen.int_range(0, 255))");
        my_nodeid_list.add(identity_mgr.get_main_id());
        // connect signals
        identity_mgr.identity_arc_added.connect(identities_identity_arc_added);
        identity_mgr.identity_arc_changed.connect(identities_identity_arc_changed);
        identity_mgr.identity_arc_removing.connect(identities_identity_arc_removing);
        identity_mgr.identity_arc_removed.connect(identities_identity_arc_removed);
        identity_mgr.arc_removed.connect(identities_arc_removed);

        // register handlers for SIGINT and SIGTERM to exit
        Posix.@signal(Posix.Signal.INT, safe_exit);
        Posix.@signal(Posix.Signal.TERM, safe_exit);
        // Main loop
        while (true)
        {
            tasklet.ms_wait(100);
            if (do_me_exit) break;
        }

        // Call stop_rpc.
        ArrayList<string> final_devs = new ArrayList<string>();
        final_devs.add_all(pseudonic_map.keys);
        foreach (string dev in final_devs) stop_rpc(dev);

        // Then we destroy the object NeighborhoodManager.
        neighborhood_mgr = null;
        tasklet.ms_wait(100);

        PthTaskletImplementer.kill();

        return 0;
    }

    bool do_me_exit = false;
    void safe_exit(int sig)
    {
        // We got here because of a signal. Quick processing.
        do_me_exit = true;
    }

    void stop_rpc(string dev)
    {
        string linklocal = handlednic_map[dev].linklocal;
        PseudoNetworkInterface pseudonic = pseudonic_map[dev];
        skeleton_factory.stop_stream_system_listen(pseudonic.st_listen_pathname);
        print(@"stopped stream_system_listen $(pseudonic.st_listen_pathname).\n");
        neighborhood_mgr.stop_monitor(dev);
        skeleton_factory.stop_datagram_system_listen(pseudonic.listen_pathname);
        print(@"stopped datagram_system_listen $(pseudonic.listen_pathname).\n");
        pseudonic_map.unset(dev);
    }

    class PseudoNetworkInterface : Object
    {
        public PseudoNetworkInterface(string dev, string listen_pathname, string send_pathname, string mac)
        {
            this.dev = dev;
            this.listen_pathname = listen_pathname;
            this.send_pathname = send_pathname;
            this.mac = mac;
            nic = new NeighborhoodNetworkInterface(this);
        }
        public string mac {get; private set;}
        public string send_pathname {get; private set;}
        public string listen_pathname {get; private set;}
        public string dev {get; private set;}
        public string linklocal {get; set;}
        public string st_listen_pathname {get; set;}
        public INeighborhoodNetworkInterface nic {get; set;}
    }

    class HandledNic : Object
    {
        public HandledNic(string dev, string mac, string linklocal, INeighborhoodNetworkInterface nic)
        {
            this.dev = dev;
            this.mac = mac;
            this.linklocal = linklocal;
            this.nic = nic;
        }

        public string dev {get; private set;}
        public string mac {get; private set;}
        public string linklocal {get; private set;}
        public INeighborhoodNetworkInterface nic {get; private set;}
    }

    class NodeArc : Object
    {
        public NodeArc(INeighborhoodArc neighborhood_arc, IdmgmtArc i_arc)
        {
            this.neighborhood_arc = neighborhood_arc;
            this.i_arc = i_arc;
        }
        public INeighborhoodArc neighborhood_arc;
        public IdmgmtArc i_arc; // for module Identities
    }
}