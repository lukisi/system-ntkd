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
    bool schedule_task_prepare_enter(string task)
    {
        if (task.has_prefix("prepare_enter,"))
        {
            string remain = task.substring("prepare_enter,".length);
            string[] args = remain.split(",");
            if (args.length != 3) error("bad args num in task 'prepare_enter'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'prepare_enter'");
            int64 my_id;
            if (! int64.try_parse(args[1], out my_id)) error("bad args my_id in task 'prepare_enter'");
            int64 enter_id;
            if (! int64.try_parse(args[2], out enter_id)) error("bad args enter_id in task 'prepare_enter'");
            print(@"INFO: in $(ms_wait) ms will do prepare_enter from parent identity #$(my_id).\n");
            PrepareEnterTasklet s = new PrepareEnterTasklet(
                (int)ms_wait,
                (int)my_id,
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
            int my_id,
            int enter_id)
        {
            this.ms_wait = ms_wait;
            this.my_id = my_id;
            this.enter_id = enter_id;
        }
        private int ms_wait;
        private int my_id;
        private int enter_id;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // TODO
            return null;
        }
    }

    bool schedule_task_enter(string task)
    {
        if (task.has_prefix("enter,"))
        {
            string remain = task.substring("enter,".length);
            string[] args = remain.split(",");
            if (args.length != 2) error("bad args num in task 'enter'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'enter'");
            int64 my_id;
            if (! int64.try_parse(args[1], out my_id)) error("bad args my_id in task 'enter'");
            print(@"INFO: in $(ms_wait) ms will do enter from parent identity #$(my_id).\n");
            EnterTasklet s = new EnterTasklet(
                (int)(ms_wait),
                (int)my_id);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class EnterTasklet : Object, ITaskletSpawnable
    {
        public EnterTasklet(
            int ms_wait,
            int my_id)
        {
            this.ms_wait = ms_wait;
            this.my_id = my_id;
        }
        private int ms_wait;
        private int my_id;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // TODO
            return null;
        }
    }
}