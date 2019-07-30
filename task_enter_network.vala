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
    void per_identity_hooking_do_prepare_enter(IdentityData id, int enter_id)
    {
        print(@"Signal Hooking.do_prepare_enter: For identity $(id.nodeid.id) with enter_id $(enter_id).\n");
        EnterNetwork.prepare_enter(enter_id, id);
    }

    void per_identity_hooking_do_finish_enter(IdentityData id,
        int enter_id, int guest_gnode_level, EntryData entry_data, int go_connectivity_position)
    {
        print(@"Signal Hooking.do_finish_enter: For identity $(id.nodeid.id) with enter_id $(enter_id).\n");
        print(@"     With guest_gnode_level $(guest_gnode_level) on network_id $(entry_data.network_id).\n");
        IdentityData new_id = EnterNetwork.enter(enter_id, id, entry_data.network_id,
            guest_gnode_level, go_connectivity_position,
            entry_data.pos,
            entry_data.elderships);
        print(@"Completed do_finish_enter: New identity is $(new_id.nodeid.id).\n");
    }
*/
    bool schedule_task_do_prepare_enter(string task)
    {
        if (task.has_prefix("do_prepare_enter,"))
        {
            string remain = task.substring("do_prepare_enter,".length);
            string[] args = remain.split(",");
            if (args.length != 3) error("bad args num in task 'do_prepare_enter'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'do_prepare_enter'");
            int64 local_identity_index;
            if (! int64.try_parse(args[1], out local_identity_index)) error("bad args local_identity_index in task 'do_prepare_enter'");
            int64 enter_id;
            if (! int64.try_parse(args[2], out enter_id)) error("bad args enter_id in task 'do_prepare_enter'");
            print(@"INFO: in $(ms_wait) ms will do do_prepare_enter from parent identity #$(local_identity_index).\n");
            PrepareEnterTasklet s = new PrepareEnterTasklet(
                (int)ms_wait,
                (int)local_identity_index,
                (int)enter_id);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class PrepareEnterTasklet : Object, ITaskletSpawnable
    {
        public PrepareEnterTasklet(
            int ms_wait,
            int local_identity_index,
            int enter_id)
        {
            this.ms_wait = ms_wait;
            this.local_identity_index = local_identity_index;
            this.enter_id = enter_id;
        }
        private int ms_wait;
        private int local_identity_index;
        private int enter_id;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // find IdentityData
            IdentityData? identity_data = find_local_identity_by_index(local_identity_index);
            assert(identity_data != null);

            print(@"PseudoSignal Hooking.do_prepare_enter: For identity #$(local_identity_index) with enter_id $(enter_id).\n");
            EnterNetwork.prepare_enter(enter_id, identity_data);

            return null;
        }
    }

    bool schedule_task_do_finish_enter(string task)
    {
        if (task.has_prefix("do_finish_enter,"))
        {
            string remain = task.substring("do_finish_enter,".length);
            string[] args = remain.split(",");
            if (args.length != 8) error("bad args num in task 'do_finish_enter'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'do_finish_enter'");
            int64 local_identity_index;
            if (! int64.try_parse(args[1], out local_identity_index)) error("bad args local_identity_index in task 'do_finish_enter'");
            int64 enter_id;
            if (! int64.try_parse(args[2], out enter_id)) error("bad args enter_id in task 'do_finish_enter'");
            int64 network_id;
            if (! int64.try_parse(args[3], out network_id)) error("bad args network_id in task 'do_finish_enter'");
            int64 guest_gnode_level;
            if (! int64.try_parse(args[4], out guest_gnode_level)) error("bad args guest_gnode_level in task 'do_finish_enter'");
            int64 go_connectivity_position;
            if (! int64.try_parse(args[5], out go_connectivity_position)) error("bad args go_connectivity_position in task 'do_finish_enter'");
            ArrayList<int> in_g_naddr = new ArrayList<int>();
            int host_level;
            {
                string[] parts = args[6].split(":");
                host_level = levels - (parts.length - 1);
                if (host_level <= guest_gnode_level) error("bad parts num in in_g_naddr in task 'do_finish_enter'");
                for (int i = 0; i < parts.length; i++)
                {
                    int64 element;
                    if (! int64.try_parse(parts[i], out element)) error("bad parts element in in_g_naddr in task 'do_finish_enter'");
                    in_g_naddr.add((int)element);
                }
            }
            ArrayList<int> in_g_elderships = new ArrayList<int>();
            {
                string[] parts = args[7].split(":");
                if (host_level != levels - (parts.length - 1)) error("bad parts num in in_g_elderships in task 'do_finish_enter'");
                for (int i = 0; i < parts.length; i++)
                {
                    int64 element;
                    if (! int64.try_parse(parts[i], out element)) error("bad parts element in in_g_elderships in task 'do_finish_enter'");
                    in_g_elderships.add((int)element);
                }
            }
            print(@"INFO: in $(ms_wait) ms will do do_finish_enter from parent identity #$(local_identity_index).\n");
            FinishEnterTasklet s = new FinishEnterTasklet(
                (int)ms_wait,
                (int)local_identity_index,
                (int)enter_id,
                network_id,
                (int)guest_gnode_level,
                (int)go_connectivity_position,
                in_g_naddr,
                in_g_elderships);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class FinishEnterTasklet : Object, ITaskletSpawnable
    {
        public FinishEnterTasklet(
            int ms_wait,
            int local_identity_index,
            int enter_id,
            int64 network_id,
            int guest_gnode_level,
            int go_connectivity_position,
            ArrayList<int> in_g_naddr,
            ArrayList<int> in_g_elderships)
        {
            this.ms_wait = ms_wait;
            this.local_identity_index = local_identity_index;
            this.enter_id = enter_id;
            this.network_id = network_id;
            this.guest_gnode_level = guest_gnode_level;
            this.go_connectivity_position = go_connectivity_position;
            this.in_g_naddr = in_g_naddr;
            this.in_g_elderships = in_g_elderships;
        }
        private int ms_wait;
        private int local_identity_index;
        private int enter_id;
        private int64 network_id;
        private int guest_gnode_level;
        private int go_connectivity_position;
        private ArrayList<int> in_g_naddr;
        private ArrayList<int> in_g_elderships;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // find IdentityData
            IdentityData? identity_data = find_local_identity_by_index(local_identity_index);
            assert(identity_data != null);

            print(@"PseudoSignal Hooking.do_finish_enter: For identity #$(local_identity_index) with enter_id $(enter_id).\n");
            print(@"     With guest_gnode_level $(guest_gnode_level) on network_id $(network_id).\n");
            IdentityData new_id = EnterNetwork.enter(enter_id, identity_data, network_id,
                guest_gnode_level, go_connectivity_position,
                in_g_naddr,
                in_g_elderships);
            print(@"Completed do_finish_enter: New identity is $(new_id.nodeid.id).\n");

            return null;
        }
    }
}