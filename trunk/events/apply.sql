CREATE EVENT flexviews.apply_views
ON SCHEDULE EVERY '10' MINUTE
DO CALL flexviews.refresh_all('APPLY',flexviews.uow_from_dtime(now()));
