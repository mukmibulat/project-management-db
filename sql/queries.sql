select
    task_id,
    project_id,
    title,
    status,
    priority,
    due_date,
    created_at
from tasks
where status in ('new', 'in_progress')
  and priority in ('high', 'medium')
  and due_date is not null
order by due_date asc, created_at asc, task_id asc
limit 10;

select
    t.task_id,
    p.name as project_name,
    t.title as task_title,
    t.status,
    t.priority,
    creator.full_name as created_by_name,
    assignee.full_name as assignee_name,
    t.due_date
from tasks t
inner join projects p on p.project_id = t.project_id
inner join users creator on creator.user_id = t.created_by
inner join users assignee on assignee.user_id = t.assignee_id
where t.status in ('new', 'in_progress')
order by p.project_id, t.due_date nulls last, t.task_id;

select
    p.name as project_name,
    t.title as task_title,
    u.full_name as author_name,
    pm.role as project_role,
    c.created_at as commented_at,
    c.content
from comments c
inner join tasks t on t.task_id = c.task_id
inner join projects p on p.project_id = t.project_id
inner join users u on u.user_id = c.user_id
inner join project_members pm
    on pm.project_id = t.project_id
   and pm.user_id = c.user_id
where t.priority = 'high'
order by c.created_at desc, c.comment_id desc
limit 20;

select
    l.name as label_name,
    coalesce(l.color, 'Не указан') as label_color,
    p.name as project_name,
    t.task_id,
    t.title as task_title,
    t.status,
    t.priority,
    tl.added_at
from task_labels tl
inner join labels l on l.label_id = tl.label_id
inner join tasks t on t.task_id = tl.task_id
inner join projects p on p.project_id = t.project_id
order by l.name, p.project_id, t.task_id;

select
    t.task_id,
    p.name as project_name,
    t.title as task_title,
    t.status,
    t.priority,
    coalesce(u.full_name, 'Не назначен') as assignee_name
from tasks t
inner join projects p on p.project_id = t.project_id
left join task_labels tl on tl.task_id = t.task_id
left join users u on u.user_id = t.assignee_id
where tl.task_id is null
order by t.task_id;

select
    p.project_id,
    p.name as project_name,
    u.user_id,
    u.full_name,
    pm.role,
    pm.joined_at
from project_members pm
inner join projects p on p.project_id = pm.project_id
inner join users u on u.user_id = pm.user_id
left join tasks t
    on t.project_id = pm.project_id
   and t.assignee_id = pm.user_id
where t.task_id is null
order by p.project_id, pm.role, u.user_id;

select
    p.project_id,
    p.name as project_name,
    count(distinct t.task_id) as total_tasks,
    count(distinct t.task_id) filter (where t.status = 'completed') as completed_tasks,
    count(te.time_entry_id) as time_entries_count,
    coalesce(sum(te.hours), 0) as total_hours,
    round(avg(te.hours), 2) as avg_entry_hours
from projects p
left join tasks t on t.project_id = p.project_id
left join time_entries te on te.task_id = t.task_id
group by p.project_id, p.name
having coalesce(sum(te.hours), 0) >= 47
order by total_hours desc, p.project_id;

select
    u.user_id,
    u.full_name,
    count(distinct t.project_id) as projects_logged_count,
    count(te.time_entry_id) as entries_count,
    sum(te.hours) as total_hours,
    round(avg(te.hours), 2) as avg_hours_per_entry,
    max(te.hours) as max_single_entry_hours
from users u
inner join time_entries te on te.user_id = u.user_id
inner join tasks t on t.task_id = te.task_id
group by u.user_id, u.full_name
having sum(te.hours) > 25
order by total_hours desc, u.user_id;

select
    t.task_id,
    p.name as project_name,
    t.title as task_title,
    t.status,
    t.priority,
    (
        select sum(te_inner.hours)
        from time_entries te_inner
        where te_inner.task_id = t.task_id
    ) as task_total_hours
from tasks t
inner join projects p on p.project_id = t.project_id
where t.task_id in (
    select te.task_id
    from time_entries te
    group by te.task_id
    having sum(te.hours) > (
        select avg(task_hours)
        from (
            select sum(hours) as task_hours
            from time_entries
            group by task_id
        ) avg_sub
    )
)
order by task_total_hours desc, t.task_id;

select
    p.project_id,
    p.name as project_name,
    p.start_date,
    p.end_date
from projects p
where exists (
    select 1
    from tasks t
    where t.project_id = p.project_id
      and t.status = 'completed'
      and t.priority = 'high'
)
  and not exists (
    select 1
    from tasks t
    where t.project_id = p.project_id
      and t.status = 'cancelled'
)
order by p.project_id;

with task_hours as (
    select
        t.project_id,
        t.task_id,
        t.status,
        coalesce(sum(te.hours), 0) as hours_spent
    from tasks t
    left join time_entries te on te.task_id = t.task_id
    group by t.project_id, t.task_id, t.status
),
project_summary as (
    select
        p.project_id,
        p.name as project_name,
        count(th.task_id) as total_tasks,
        count(*) filter (where th.status = 'completed') as completed_tasks,
        sum(th.hours_spent) as total_hours
    from projects p
    left join task_hours th on th.project_id = p.project_id
    group by p.project_id, p.name
),
portfolio_avg as (
    select round(avg(total_hours), 2) as avg_project_hours
    from project_summary
)
select
    ps.project_id,
    ps.project_name,
    ps.total_tasks,
    ps.completed_tasks,
    round(ps.completed_tasks * 100.0 / nullif(ps.total_tasks, 0), 1) as completion_pct,
    ps.total_hours,
    pa.avg_project_hours,
    round(ps.total_hours - pa.avg_project_hours, 2) as diff_from_avg_hours
from project_summary ps
cross join portfolio_avg pa
order by ps.total_hours desc, ps.project_id;

with member_project_hours as (
    select
        t.project_id,
        p.name as project_name,
        u.user_id,
        u.full_name,
        pm.role,
        sum(te.hours) as user_hours
    from time_entries te
    inner join tasks t on t.task_id = te.task_id
    inner join projects p on p.project_id = t.project_id
    inner join users u on u.user_id = te.user_id
    inner join project_members pm
        on pm.project_id = t.project_id
       and pm.user_id = te.user_id
    group by t.project_id, p.name, u.user_id, u.full_name, pm.role
)
select
    project_id,
    project_name,
    full_name,
    role,
    user_hours,
    sum(user_hours) over (partition by project_id) as project_total_hours,
    round(user_hours * 100.0 / sum(user_hours) over (partition by project_id), 1) as share_pct,
    rank() over (partition by project_id order by user_hours desc) as hours_rank,
    row_number() over (partition by project_id order by user_hours desc, user_id asc) as row_num
from member_project_hours
order by project_id, row_num;

select
    u.user_id,
    u.full_name,
    u.email
from time_entries te
inner join users u on u.user_id = te.user_id

except

select
    u.user_id,
    u.full_name,
    u.email
from tasks t
inner join users u on u.user_id = t.assignee_id

order by user_id;

select
    t.task_id,
    p.name as project_name,
    concat('[', upper(t.priority), '] ', t.title) as labeled_title,
    coalesce(split_part(u.email, '@', 1), 'unassigned') as assignee_login,
    t.created_at::date as created_date,
    t.due_date,
    t.completed_at::date as completed_date,
    case
        when t.status = 'cancelled' then 'Отменена'
        when t.status = 'completed' and t.due_date is null then 'Завершена без срока'
        when t.status = 'completed' and t.completed_at::date <= t.due_date then 'Завершена в срок'
        when t.status = 'completed' then 'Завершена с опозданием'
        when t.due_date is null then 'В работе (срок не задан)'
        when t.due_date < current_date then 'Просрочена'
        else 'В работе (в пределах срока)'
    end as deadline_state,
    case
        when t.due_date is null then null
        when t.status = 'completed' then (t.due_date - t.completed_at::date)
        else (t.due_date - current_date)
    end as days_delta
from tasks t
inner join projects p on p.project_id = t.project_id
left join users u on u.user_id = t.assignee_id
order by t.task_id;

create or replace view v_task_overview as
select
    t.task_id,
    p.project_id,
    p.name as project_name,
    t.title as task_title,
    t.status,
    t.priority,
    creator.full_name as created_by_name,
    assignee.full_name as assignee_name,
    t.created_at,
    t.due_date,
    t.completed_at,
    coalesce(c_stat.comments_count, 0) as comments_count,
    coalesce(te_stat.total_hours, 0) as total_hours,
    coalesce(lbl_stat.labels_list, 'Без меток') as labels_list
from tasks t
inner join projects p on p.project_id = t.project_id
inner join users creator on creator.user_id = t.created_by
left join users assignee on assignee.user_id = t.assignee_id
left join (
    select task_id, count(*) as comments_count
    from comments
    group by task_id
) c_stat on c_stat.task_id = t.task_id
left join (
    select task_id, sum(hours) as total_hours
    from time_entries
    group by task_id
) te_stat on te_stat.task_id = t.task_id
left join (
    select
        tl.task_id,
        string_agg(l.name, ', ' order by l.name) as labels_list
    from task_labels tl
    inner join labels l on l.label_id = tl.label_id
    group by tl.task_id
) lbl_stat on lbl_stat.task_id = t.task_id;

select
    task_id,
    project_name,
    task_title,
    status,
    coalesce(assignee_name, 'Не назначен') as assignee_name,
    due_date,
    comments_count,
    total_hours,
    labels_list
from v_task_overview
where status in ('new', 'in_progress')
  and priority = 'high'
order by due_date nulls last, total_hours desc, task_id;

select
    t.created_at as event_time,
    'Создание задачи' as event_type,
    u.full_name as actor_name,
    t.title as details
from tasks t
inner join users u on u.user_id = t.created_by
where t.project_id = 1

union all

select
    c.created_at as event_time,
    'Комментарий' as event_type,
    u.full_name as actor_name,
    concat(t.title, ': ', left(c.content, 60)) as details
from comments c
inner join tasks t on t.task_id = c.task_id
inner join users u on u.user_id = c.user_id
where t.project_id = 1

union all

select
    te.created_at as event_time,
    'Списание времени' as event_type,
    u.full_name as actor_name,
    concat(t.title, ' — ', te.hours, ' ч.') as details
from time_entries te
inner join tasks t on t.task_id = te.task_id
inner join users u on u.user_id = te.user_id
where t.project_id = 1

order by event_time desc, event_type
limit 25;
