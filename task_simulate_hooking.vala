/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2018-2019 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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
using Netsukuku.Qspn;
using TaskletSystem;

namespace Netsukuku
{
/*
    void per_identity_hooking_same_network(IdentityData id, IIdentityArc _ia)
    {
        IdentityArc ia = ((HookingIdentityArc)_ia).ia;
        ia.network_id = null;
        print(@"Signal Hooking.same_network: adding qspn_arc for id-arc " +
            @"$(id.nodeid.id)-$(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)ia.arc).id).\n");
        UpdateGraph.add_arc(ia); // this will set ia.qspn_arc
    }

    void per_identity_hooking_another_network(IdentityData id, IIdentityArc _ia, int64 network_id)
    {
        IdentityArc ia = ((HookingIdentityArc)_ia).ia;
        ia.network_id = network_id;
        print(@"Signal Hooking.another_network: saving network_id $(network_id) for id-arc " +
            @"$(id.nodeid.id)-$(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)ia.arc).id).\n");
    }
*/
    bool schedule_task_same_network(string task)
    {
        if (task.has_prefix("same_network,"))
        {
            string remain = task.substring("same_network,".length);
            string[] args = remain.split(",");
            if (args.length != 5) error("bad args num in task 'same_network'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'same_network'");
            int64 local_identity_index;
            if (! int64.try_parse(args[1], out local_identity_index)) error("bad args local_identity_index in task 'same_network'");
            string arc_my_dev = args[2];
            string arc_peer_mac = args[3];
            string id_arc_peer_mac = args[4];
            print(@"INFO: in $(ms_wait) ms will do same_network from parent identity #$(local_identity_index).\n");
            SameNetworkTasklet s = new SameNetworkTasklet(
                (int)ms_wait,
                (int)local_identity_index,
                arc_my_dev,
                arc_peer_mac,
                id_arc_peer_mac);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class SameNetworkTasklet : Object, ITaskletSpawnable
    {
        public SameNetworkTasklet(
            int ms_wait,
            int local_identity_index,
            string arc_my_dev,
            string arc_peer_mac,
            string id_arc_peer_mac)
        {
            this.ms_wait = ms_wait;
            this.local_identity_index = local_identity_index;
            this.arc_my_dev = arc_my_dev;
            this.arc_peer_mac = arc_peer_mac;
            this.id_arc_peer_mac = id_arc_peer_mac;
        }
        private int ms_wait;
        private int local_identity_index;
        private string arc_my_dev;
        private string arc_peer_mac;
        private string id_arc_peer_mac;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // find IdentityData and IdentityArc
            IdentityData? identity_data = find_local_identity_by_index(local_identity_index);
            assert(identity_data != null);
            IdentityArc? ia = null;
            foreach (IdentityArc _ia in identity_data.identity_arcs)
            {
                if (_ia.arc.get_dev() == arc_my_dev &&
                    _ia.arc.get_peer_mac() == arc_peer_mac &&
                    _ia.id_arc.get_peer_mac() == id_arc_peer_mac)
                {
                    ia = _ia;
                    break;
                }
            }
            assert(ia != null);

            // TODO
            ia.network_id = null;
            print(@"PseudoSignal Hooking.same_network: adding qspn_arc for id-arc " +
                @"$(identity_data.nodeid.id)-$(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)ia.arc).id).\n");
            UpdateGraph.add_arc(ia); // this will set ia.qspn_arc

            return null;
        }
    }

    bool schedule_task_another_network(string task)
    {
        if (task.has_prefix("another_network,"))
        {
            string remain = task.substring("another_network,".length);
            string[] args = remain.split(",");
            if (args.length != 2) error("bad args num in task 'another_network'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'another_network'");
            int64 local_identity_index;
            if (! int64.try_parse(args[1], out local_identity_index)) error("bad args local_identity_index in task 'another_network'");
            string arc_my_dev = args[2];
            string arc_peer_mac = args[3];
            string id_arc_peer_mac = args[4];
            int64 network_id;
            if (! int64.try_parse(args[1], out network_id)) error("bad args network_id in task 'another_network'");
            print(@"INFO: in $(ms_wait) ms will do another_network from parent identity #$(local_identity_index).\n");
            AnotherNetworkTasklet s = new AnotherNetworkTasklet(
                (int)ms_wait,
                (int)local_identity_index,
                arc_my_dev,
                arc_peer_mac,
                id_arc_peer_mac,
                network_id);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class AnotherNetworkTasklet : Object, ITaskletSpawnable
    {
        public AnotherNetworkTasklet(
            int ms_wait,
            int local_identity_index,
            string arc_my_dev,
            string arc_peer_mac,
            string id_arc_peer_mac,
            int64 network_id)
        {
            this.ms_wait = ms_wait;
            this.local_identity_index = local_identity_index;
            this.arc_my_dev = arc_my_dev;
            this.arc_peer_mac = arc_peer_mac;
            this.id_arc_peer_mac = id_arc_peer_mac;
            this.network_id = network_id;
        }
        private int ms_wait;
        private int local_identity_index;
        private string arc_my_dev;
        private string arc_peer_mac;
        private string id_arc_peer_mac;
        private int64 network_id;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // find IdentityData and IdentityArc
            IdentityData? identity_data = find_local_identity_by_index(local_identity_index);
            assert(identity_data != null);
            IdentityArc? ia = null;
            foreach (IdentityArc _ia in identity_data.identity_arcs)
            {
                if (_ia.arc.get_dev() == arc_my_dev &&
                    _ia.arc.get_peer_mac() == arc_peer_mac &&
                    _ia.id_arc.get_peer_mac() == id_arc_peer_mac)
                {
                    ia = _ia;
                    break;
                }
            }
            assert(ia != null);

            // TODO
            ia.network_id = network_id;
            print(@"PseudoSignal Hooking.another_network: saving network_id $(network_id) for id-arc " +
                @"$(identity_data.nodeid.id)-$(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)ia.arc).id).\n");

            return null;
        }
    }
}