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
    class NeighborhoodIPRouteManager : Object, INeighborhoodIPRouteManager
    {
        public void add_address(string my_addr, string my_dev)
        {
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"address", @"add", @"$(my_addr)", @"dev", @"$(my_dev)"}));
        }

        public void add_neighbor(string my_addr, string my_dev, string neighbor_addr)
        {
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"route", @"add", @"$(neighbor_addr)", @"dev", @"$(my_dev)", @"src", @"$(my_addr)"}));
        }

        public void remove_neighbor(string my_addr, string my_dev, string neighbor_addr)
        {
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"route", @"del", @"$(neighbor_addr)", @"dev", @"$(my_dev)", @"src", @"$(my_addr)"}));
        }

        public void remove_address(string my_addr, string my_dev)
        {
            fake_cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"address", @"del", @"$(my_addr)/32", @"dev", @"$(my_dev)"}));
        }
    }

    class NeighborhoodStubFactory : Object, INeighborhoodStubFactory
    {
        public INeighborhoodManagerStub
        get_broadcast_for_radar(INeighborhoodNetworkInterface nic)
        {
            IAddressManagerStub addrstub = stub_factory.get_stub_whole_node_broadcast_for_radar(nic);
            NeighborhoodManagerStubHolder ret = new NeighborhoodManagerStubHolder(addrstub);
            return ret;
        }

        public INeighborhoodManagerStub
        get_unicast(
            INeighborhoodArc arc,
            bool wait_reply = true)
        {
            IAddressManagerStub addrstub = stub_factory.get_stub_whole_node_unicast(arc, wait_reply);
            NeighborhoodManagerStubHolder ret = new NeighborhoodManagerStubHolder(addrstub);
            return ret;
        }
    }

    class NeighborhoodQueryCallerInfo : Object, INeighborhoodQueryCallerInfo
    {
        public INeighborhoodNetworkInterface?
        is_from_broadcast(CallerInfo _rpc_caller)
        {
            string? my_dev = skeleton_factory.from_caller_get_mydev(_rpc_caller);
            if (my_dev == null) return null;
            PseudoNetworkInterface pseudonic = pseudonic_map[my_dev];
            return pseudonic.nic;
        }

        public INeighborhoodArc?
        is_from_unicast(CallerInfo _rpc_caller, Gee.List<INeighborhoodArc> arcs)
        {
            if (_rpc_caller is StreamCallerInfo)
            {
                StreamCallerInfo rpc_caller = (StreamCallerInfo)_rpc_caller;
                if (rpc_caller.listener is StreamSystemListener)
                {
                    string st_listen_pathname = ((StreamSystemListener)rpc_caller.listener).listen_pathname;
                    if (rpc_caller.src_nic is NeighbourSrcNic)
                    {
                        string neighbour_mac = ((NeighbourSrcNic)rpc_caller.src_nic).mac;
                        foreach (INeighborhoodArc arc in arcs)
                        {
                            if (arc.neighbour_mac == neighbour_mac)
                            {
                                PseudoNetworkInterface pseudonic = ((NeighborhoodNetworkInterface)arc.nic).pseudonic;
                                if (pseudonic.st_listen_pathname == st_listen_pathname)
                                    return arc;
                            }
                        }
                        return null;
                    }
                    else error("not rpc_caller.src_nic is NeighbourSrcNic");
                }
                else error("not rpc_caller.listener is StreamSystemListener");
            }
            else return null;
        }
    }

    class NeighborhoodNetworkInterface : Object, INeighborhoodNetworkInterface
    {
        public NeighborhoodNetworkInterface(PseudoNetworkInterface pseudonic)
        {
            this.pseudonic = pseudonic;
        }
        public PseudoNetworkInterface pseudonic {get; private set;}

        public string dev {
            get {
                return pseudonic.dev;
            }
        }

        public string mac {
            get {
                return pseudonic.mac;
            }
        }

        public long measure_rtt(string peer_addr, string peer_mac, string my_dev, string my_addr) throws NeighborhoodGetRttError
        {
            fake_cm.single_command(new ArrayList<string>.wrap({
                "ping", "-n", "-q", "-c", "1", @"$(peer_addr)"}));
            return 1000;
            // TODO
        }
    }
}