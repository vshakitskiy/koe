select id, username, password_hash
from users
where username = $1;
