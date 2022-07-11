module util.signal;

bool rising_edge (bool old_value, bool new_value) { return !old_value  &&  new_value; }
bool falling_edge(bool old_value, bool new_value) { return  old_value  && !new_value; }