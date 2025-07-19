select id, username, password_hash
from users
where id = $1;
