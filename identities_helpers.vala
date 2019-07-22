/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2017-2019 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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
using Netsukuku;
using Netsukuku.Neighborhood;
using Netsukuku.Identities;
//using Netsukuku.Qspn;
using TaskletSystem;

namespace Netsukuku
{
    class IdmgmtNetnsManager : Object, IIdmgmtNetnsManager
    {
        public void create_namespace(string ns)
        {
            tester_events.add(@"NetnsManager:create_namespace:netns '$(ns)'");
            assert(ns != "");
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"add", @"$(ns)"}));
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)",
                @"sysctl", @"net.ipv4.ip_forward=1"}));
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)",
                @"sysctl", @"net.ipv4.conf.all.rp_filter=0"}));
        }

        public void create_pseudodev(string dev, string ns, string pseudo_dev, out string pseudo_mac)
        {
            tester_events.add(@"NetnsManager:create_pseudodev:$(pseudo_dev) link $(dev) netns '$(ns)'");
            assert(ns != "");
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"link", @"add", @"dev", @"$(pseudo_dev)", @"link", @"$(dev)", @"type", @"macvlan"}));
            // (optional) set pseudo-random MAC
            string newmac = "4E";
            for (int i = 0; i < 5; i++)
            {
                uint8 b = (uint8)PRNGen.int_range(0, 256);
                string sb = b.to_string("%02x").up();
                newmac += @":$(sb)";
            }
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"link", @"set", @"dev", @"$(pseudo_dev)", @"address", @"$(newmac)"}));
            pseudo_mac = newmac.up(); // it was: pseudo_mac = macgetter.get_mac(pseudo_dev).up();
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"link", @"set", @"dev", @"$(pseudo_dev)", @"netns", @"$(ns)"}));
            // disable rp_filter
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)",
                @"sysctl", @"net.ipv4.conf.$(pseudo_dev).rp_filter=0"}));
            // arp policies
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)",
                @"sysctl", @"net.ipv4.conf.$(pseudo_dev).arp_ignore=1"}));
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)",
                @"sysctl", @"net.ipv4.conf.$(pseudo_dev).arp_announce=2"}));
            // up
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)",
                @"ip", @"link", @"set", @"dev", @"$(pseudo_dev)", @"up"}));
        }

        public void add_address(string ns, string pseudo_dev, string linklocal)
        {
            tester_events.add(@"NetnsManager:add_address:$(linklocal) dev $(pseudo_dev) netns '$(ns)'");
            // ns may be empty-string.
            ArrayList<string> argv = new ArrayList<string>();
            if (ns != "") argv.add_all_array({@"ip", @"netns", @"exec", @"$(ns)"});
            argv.add_all_array({
                @"ip", @"address", @"add", @"$(linklocal)", @"dev", @"$(pseudo_dev)"});
            fake_cm.single_command(argv);
        }

        public void add_gateway(string ns, string linklocal_src, string linklocal_dst, string dev)
        {
            tester_events.add(@"NetnsManager:add_gateway:$(linklocal_dst) dev $(dev) src $(linklocal_src) netns '$(ns)'");
            // ns may be empty-string.
            ArrayList<string> argv = new ArrayList<string>();
            if (ns != "") argv.add_all_array({@"ip", @"netns", @"exec", @"$(ns)"});
            argv.add_all_array({
                @"ip", @"route", @"add", @"$(linklocal_dst)", @"dev", @"$(dev)", @"src", @"$(linklocal_src)"});
            fake_cm.single_command(argv);
        }

        public void remove_gateway(string ns, string linklocal_src, string linklocal_dst, string dev)
        {
            tester_events.add(@"NetnsManager:remove_gateway:$(linklocal_dst) dev $(dev) src $(linklocal_src) netns '$(ns)'");
            // ns may be empty-string.
            ArrayList<string> argv = new ArrayList<string>();
            if (ns != "") argv.add_all_array({@"ip", @"netns", @"exec", @"$(ns)"});
            argv.add_all_array({
                @"ip", @"route", @"del", @"$(linklocal_dst)", @"dev", @"$(dev)", @"src", @"$(linklocal_src)"});
            fake_cm.single_command(argv);
        }

        public void flush_table(string ns)
        {
            tester_events.add(@"NetnsManager:flush_table:netns '$(ns)'");
            assert(ns != "");
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)", @"ip", @"route", @"flush", @"table", @"main"}));
        }

        public void delete_pseudodev(string ns, string pseudo_dev)
        {
            tester_events.add(@"NetnsManager:delete_pseudodev:$(pseudo_dev) netns '$(ns)'");
            assert(ns != "");
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)", @"ip", @"link", @"delete", @"$(pseudo_dev)", @"type", @"macvlan"}));
        }

        public void delete_namespace(string ns)
        {
            tester_events.add(@"NetnsManager:delete_namespace:netns '$(ns)'");
            assert(ns != "");
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"del", @"$(ns)"}));
        }
    }

    class IdmgmtStubFactory : Object, IIdmgmtStubFactory
    {
        public IIdmgmtArc? get_arc(CallerInfo rpc_caller)
        {
            NodeArc? node_arc = skeleton_factory.from_caller_get_nodearc(rpc_caller);
            if (node_arc != null) return node_arc.i_arc;
            return null;
        }

        public IIdentityManagerStub get_stub(IIdmgmtArc arc)
        {
            IdmgmtArc _arc = (IdmgmtArc)arc;
            IAddressManagerStub addrstub = stub_factory.get_stub_whole_node_unicast(_arc.neighborhood_arc);
            IdentityManagerStubHolder ret = new IdentityManagerStubHolder(addrstub);
            return ret;
        }
    }

    class IdmgmtArc : Object, IIdmgmtArc
    {
        public IdmgmtArc(INeighborhoodArc neighborhood_arc)
        {
            this.neighborhood_arc = neighborhood_arc;
            id = next_id++;
        }
        public INeighborhoodArc neighborhood_arc;
        public int id;
        private static int next_id = 0;

        public string get_dev()
        {
            return neighborhood_arc.nic.dev;
        }

        public string get_peer_mac()
        {
            return neighborhood_arc.neighbour_mac;
        }

        public string get_peer_linklocal()
        {
            return neighborhood_arc.neighbour_nic_addr;
        }
    }
}