% check D2D version and compare with current revision on github
%
% flag = arCheckVersion
%
% flag = 1 : D2D is up-to-date

function flag = arCheckVersion(silent)

global ar

if(~exist('silent','var'))
    silent = false;
end

[has_git, is_repo] = arCheckGit(ar.info.ar_path);

if(has_git && is_repo)
    % find current revision of d2d
    old_path = pwd;
    cd(ar.info.ar_path)
    [~, cmdout] = system('git rev-parse HEAD');
    cd(old_path)
    
    ar.info.revision = deblank(cmdout);
    
    update_msg = 'There is a newer version available on github! Please check http://www.data2dynamics.org for updates or run "arUpdateD2D".';
    
    % get current SHA from github and compare with installed revision
    try
        if(exist('webread', 'file'))
            gh_data = webread('https://api.github.com/repos/Data2Dynamics/d2d/git/refs/heads/master');
            gh_data = gh_data.object.sha;
        elseif(exist('urlread', 'file'))
            % Code path for older versions of MATLAB
            gh_data = urlread('https://api.github.com/repos/Data2Dynamics/d2d/git/refs/heads/master');
            gh_data = gh_data(strfind(gh_data, '"sha":')+7:end);
            br      = strfind(gh_data, '"');
            gh_data = gh_data(1:br(1)-1);
        end
        if(~isempty(gh_data) && ~strcmp(deblank(gh_data),ar.info.revision)) && ~silent
            warning(update_msg);
        end
    catch
        if(~silent)
            warning('Could not connect to github. Version checking cancelled.')
        end
    end
else
    ar.info.revision = [];
end

if (nargout==1)
    if exist('gh_data','var')
        flag = (~isempty(gh_data) && strcmp(deblank(gh_data),ar.info.revision));
    else
        flag = false;
    end
end
