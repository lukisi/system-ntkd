using Gee;

void main()
{
    ArrayList<int> l = new ArrayList<int>();
    l.add(1);
    l.add(2);
    foreach (int i in l) print(@"$(i)\n");
}
