% Calculate chi^2 value and number of data points
%
% arChi2(sensi, pTrial)
%   sensi:          propagate sensitivities         [false]
%   pTrial:         trial parameter of fitting

function arChi2(sensi, pTrial)

global ar

if(~isfield(ar, 'fevals'))
    ar.fevals = 0; 
end
ar.fevals = ar.fevals + 1;

if(~exist('sensi', 'var'))
	sensi = false;
end
if(exist('pTrial', 'var'))
	ar.p(ar.qFit==1) = pTrial;
end

silent = nargin~=0;

ar.ndata = 0;
ar.nprior = 0;
ar.nconstr = 0;

ar.chi2 = 0;
ar.chi2err = 0;
ar.chi2prior = 0;
ar.chi2constr = 0;
ar.chi2fit = 0;

if(~isfield(ar,'res'))
    ar.res = [];
end
if(~isfield(ar,'sres'))
    ar.sres = [];
end
if(~isfield(ar,'constr'))
    ar.constr = [];
end
if(~isfield(ar,'sconstr'))
    ar.sconstr = [];
end

nm = length(ar.model);
np = length(ar.p);

if(~isfield(ar.config,'useFitErrorCorrection'))
    ar.config.useFitErrorCorrection = true;
end

% correction for error fitting
for jm = 1:nm
    if(isfield(ar.model(jm), 'data'))
        nd = length(ar.model(jm).data);
        for jd = 1:nd
            if(ar.model(jm).data(jd).has_yExp)
                ar.ndata = ar.ndata + sum(ar.model(jm).data(jd).ndata(ar.model(jm).data(jd).qFit==1));
            end
        end
    end
end
if(ar.ndata>0 && ar.config.fiterrors == 1 && ar.config.useFitErrorCorrection)
    if(ar.ndata-sum(ar.qError~=1 & ar.qFit==1) < sum(ar.qError~=1 & ar.qFit==1))
        ar.config.fiterrors_correction = 1;
        if(~ar.config.fiterrors_correction_warning)
            warning('ar.config.fiterrors_correction_warning : turning off bias correction, not enough data'); %#ok<WNTAG>
            ar.config.fiterrors_correction_warning = true;
        end
    else
        ar.config.fiterrors_correction = ar.ndata/(ar.ndata-sum(ar.qError~=1 & ar.qFit==1));
        ar.config.fiterrors_correction_warning = false;
    end
else
    ar.config.fiterrors_correction = 1;
end

try
    arSimu(sensi, ~isfield(ar.model(jm), 'data'));
    has_error = false;
catch error_id
    if(~silent)
        disp(error_id.message);
    end
    has_error = true;
end

useMSextension = false;

resindex = 1;
sresindex = 1;

% data
for jm = 1:nm
    if(isfield(ar.model(jm), 'data'))
        nd = length(ar.model(jm).data);
        for jd = 1:nd
            if(ar.model(jm).data(jd).has_yExp)
                ar.chi2 = ar.chi2 + sum(ar.model(jm).data(jd).chi2(ar.model(jm).data(jd).qFit==1));
                
                if(useMSextension && isfield(ar, 'ms_count_snips') && ~isempty(ar.model(jm).data(jd).ms_index))
                    
                else
                    % collect residuals for fitting
                    tmpres = ar.model(jm).data(jd).res(:,ar.model(jm).data(jd).qFit==1);
                    ar.res(resindex:(resindex+length(tmpres(:))-1)) = tmpres;
                    resindex = resindex+length(tmpres(:));
                    
                    if(ar.config.fiterrors == 1)
                        ar.chi2err = ar.chi2err + sum(ar.model(jm).data(jd).chi2err(ar.model(jm).data(jd).qFit==1));
                        tmpreserr = ar.model(jm).data(jd).reserr(:,ar.model(jm).data(jd).qFit==1);
                        ar.res(resindex:(resindex+length(tmpreserr(:))-1)) = tmpreserr;
                        resindex = resindex+length(tmpreserr(:));
                    end
                    
                    % collect sensitivities for fitting
                    if(ar.config.useSensis && sensi)
                        tmptmpsres = ar.model(jm).data(jd).sres(:,ar.model(jm).data(jd).qFit==1,:);
                        tmpsres = zeros(length(tmpres(:)), np);
                        tmpsres(:,ar.model(jm).data(jd).pLink) = reshape(tmptmpsres, ...
                            length(tmpres(:)), sum(ar.model(jm).data(jd).pLink));
                        ar.sres(sresindex:(sresindex+length(tmpres(:))-1),:) = tmpsres;
                        sresindex = sresindex+length(tmpres(:));
                        
                        if(ar.config.fiterrors == 1)
                            tmpsreserr = zeros(length(tmpreserr(:)), np);
                            tmpsreserr(:,ar.model(jm).data(jd).pLink) = reshape(ar.model(jm).data(jd).sreserr(:,ar.model(jm).data(jd).qFit==1,:), ...
                                length(tmpreserr(:)), sum(ar.model(jm).data(jd).pLink));
                            ar.sres(sresindex:(sresindex+length(tmpres(:))-1),:) = tmpsreserr;
                            sresindex = sresindex+length(tmpres(:));
                        end
                    end
                end
            end
        end
    end
end

% constraints
constrindex = 1;
sconstrindex = 1;

% steady state conditions
qRelativeToInitialValue = true;
for jm = 1:nm
    nc = length(ar.model(jm).condition);
    for jc = 1:nc
        if(isfield(ar.model(jm).condition(jc), 'qSteadyState'))
            qss = ar.model(jm).condition(jc).qSteadyState==1;
            if(sum(qss)>0)
                if(qRelativeToInitialValue)
                    if(isfield(ar.model(jm).condition(jc), 'xExpSimu'))
                        x = ar.model(jm).condition(jc).xExpSimu(1,qss);
                    else
                        x = ar.model(jm).condition(jc).xFineSimu(1,qss);
                    end
                    dxdt = ar.model(jm).condition(jc).dxdt(qss);
                    tmpconstr = (dxdt ./ x) ./ ar.model(jm).condition(jc).stdSteadyState(qss);
                    ar.constr(constrindex:(constrindex+length(tmpconstr(:))-1)) = tmpconstr;
                    constrindex = constrindex+length(tmpconstr(:));
                    ar.nconstr = ar.nconstr + sum(qss);
                    ar.chi2constr = ar.chi2constr + sum(tmpconstr.^2);
                    
                    if(ar.config.useSensis && sensi)
                        tmpsconstr = zeros(length(tmpconstr(:)), np);
                        if(isfield(ar.model(jm).condition(jc), 'sxExpSimu'))
                            dxdp = squeeze(ar.model(jm).condition(jc).sxExpSimu(1,qss,:));
                            dxdp(:,ar.model(jm).condition(jc).qLog10 == 1) = bsxfun(@times, ... % log trafo
                                dxdp(:,ar.model(jm).condition(jc).qLog10 == 1), ...
                                ar.model(jm).condition(jc).pNum(ar.model(jm).condition(jc).qLog10 == 1) * log(10));
                        else
                            dxdp = squeeze(ar.model(jm).condition(jc).sxFineSimu(1,qss,:));
                        end
                        ddxdtdp = ar.model(jm).condition(jc).ddxdtdp(qss,:);
                        ddxdtdp(:,ar.model(jm).condition(jc).qLog10 == 1) = bsxfun(@times, ... % log trafo
                            ddxdtdp(:,ar.model(jm).condition(jc).qLog10 == 1), ...
                            ar.model(jm).condition(jc).pNum(ar.model(jm).condition(jc).qLog10 == 1) * log(10));
                        
                        tmpsconstr(:,ar.model(jm).condition(jc).pLink) = bsxfun(@rdivide,ddxdtdp,x') - bsxfun(@times,bsxfun(@rdivide,dxdt,x.^2)', dxdp);
                        tmpsconstr = tmpsconstr ./ (ar.model(jm).condition(jc).stdSteadyState(qss)'*ones(1,np));
                        tmpsconstr(:,ar.qFit~=1) = 0;
                        
                        ar.sconstr(sconstrindex:(sconstrindex+length(tmpconstr(:))-1),:) = tmpsconstr;
                        sconstrindex = sconstrindex+length(tmpconstr(:));
                    end
                else
                    tmpconstr = ar.model(jm).condition(jc).dxdt(qss) ./ ar.model(jm).condition(jc).stdSteadyState(qss);
                    ar.constr(constrindex:(constrindex+length(tmpconstr(:))-1)) = tmpconstr;
                    constrindex = constrindex+length(tmpconstr(:));
                    ar.nconstr = ar.nconstr + sum(qss);
                    ar.chi2constr = ar.chi2constr + sum(tmpconstr.^2);
                    
                    if(ar.config.useSensis && sensi)
                        tmpsconstr = zeros(length(tmpconstr(:)), np);
                        ddxdtdp = ar.model(jm).condition(jc).ddxdtdp(qss,:);
                        ddxdtdp(:,ar.model(jm).condition(jc).qLog10 == 1) = bsxfun(@times, ... % log trafo
                            ddxdtdp(:,ar.model(jm).condition(jc).qLog10 == 1), ...
                            ar.model(jm).condition(jc).pNum(ar.model(jm).condition(jc).qLog10 == 1) * log(10));
                        ddxdtdp = bsxfun(@rdivide, ddxdtdp, ar.model(jm).condition(jc).stdSteadyState(qss)');
                        
                        tmpsconstr(:,ar.model(jm).condition(jc).pLink) = ddxdtdp;
                        tmpsconstr(:,ar.qFit~=1) = 0;
                       
                        ar.sconstr(sconstrindex:(sconstrindex+length(tmpconstr(:))-1),:) = tmpsconstr;
                        sconstrindex = sconstrindex+length(tmpconstr(:));
                    end
                end
            end
        end
    end
end

% priors
for jp=1:np
    if(ar.type(jp) == 0) % flat prior with hard bounds
    elseif(ar.type(jp) == 1) % gaussian prior
        tmpres = (ar.mean(jp)-ar.p(jp))./ar.std(jp);
        ar.res(resindex) = tmpres;
        resindex = resindex+1;
        if(ar.config.useSensis && sensi)
            tmpsres = zeros(size(ar.p));
            tmpsres(jp) = -1 ./ ar.std(jp);
            ar.sres(sresindex,:) = tmpsres;
            sresindex = sresindex+1;
        end
        ar.ndata = ar.ndata + 1;
        ar.nprior = ar.nprior + 1;
        ar.chi2 = ar.chi2 + tmpres^2;
        ar.chi2prior = ar.chi2prior + tmpres^2;
    elseif(ar.type(jp) == 2) % uniform with gaussian bounds
        tmpres = 0;
        w = 0.1;
        if(ar.p(jp) < ar.lb(jp))
            tmpres = (ar.p(jp) - ar.lb(jp))*w;
        elseif(ar.p(jp) > ar.ub(jp))
            tmpres = (ar.p(jp) - ar.ub(jp))*w;
        end
        ar.res(resindex) = tmpres;
        resindex = resindex+1;
        if(ar.config.useSensis && sensi)
            tmpsres = zeros(size(ar.p));
            tmpsres(jp) = w;
            ar.sres(sresindex,:) = tmpsres;
            sresindex = sresindex+1;
        end
        ar.ndata = ar.ndata + 1;
        ar.nprior = ar.nprior + 1;
        ar.chi2 = ar.chi2 + tmpres^2;
        ar.chi2prior = ar.chi2prior + tmpres^2;
    end
end

% % multiple shooting (difference penality)
% if(isfield(ar,'ms_count_snips'))
%     ar.ms_violation = 0;
%     for jm = 1:nm
%         for jms = 1:size(ar.model(jm).ms_link,1)
%             tmpres1 = ar.model(jm).condition(ar.model(jm).ms_link(jms,1)).xExpSimu(ar.model(jm).ms_link(jms,4),:);
%             tmpres2 = ar.model(jm).condition(ar.model(jm).ms_link(jms,2)).xExpSimu(ar.model(jm).ms_link(jms,5),:);
%             ar.ms_violation = [ar.ms_violation (log10(tmpres1) - log10(tmpres2)).^2];
%             
%             if(ar.ms_strength>0)
%                 tmpres = sqrt(ar.ms_strength) * (tmpres1 - tmpres2);
%                 ar.res(resindex:(resindex+length(tmpres(:))-1)) = tmpres;
%                 resindex = resindex+length(tmpres(:));
%                 
%                 if(ar.config.useSensis && sensi)
%                     tmpsres1 = zeros(length(tmpres(:)), np);
%                     tmpsres1(:,ar.model(jm).condition(ar.model(jm).ms_link(jms,1)).pLink) = ...
%                         reshape(ar.model(jm).condition(ar.model(jm).ms_link(jms,1)).sxExpSimu(...
%                         ar.model(jm).ms_link(jms,4),:,:), length(tmpres(:)), ...
%                         sum(ar.model(jm).condition(ar.model(jm).ms_link(jms,1)).pLink));
%                     
%                     tmpsres2 = zeros(length(tmpres(:)), np);
%                     tmpsres2(:,ar.model(jm).condition(ar.model(jm).ms_link(jms,2)).pLink) = ...
%                         reshape(ar.model(jm).condition(ar.model(jm).ms_link(jms,2)).sxExpSimu(...
%                         ar.model(jm).ms_link(jms,5),:,:), length(tmpres(:)), ...
%                         sum(ar.model(jm).condition(ar.model(jm).ms_link(jms,2)).pLink));
%                     
%                     tmpsres = sqrt(ar.ms_strength) * (tmpsres1 - tmpsres2);
%                     
%                     for j=find(ar.qLog10==1)
%                         tmpsres(:,j) = tmpsres(:,j) * 10.^ar.p(j) * log(10);
%                     end
%                     
%                     ar.sres(sresindex:(sresindex+length(tmpres(:))-1),:) = tmpsres;
%                     sresindex = sresindex+length(tmpres(:));
%                 end
%             end
%         end
%     end
% end

% % multiple shooting (log ratio penalty)
% if(isfield(ar,'ms_count_snips'))
%     ar.ms_violation = [];
%     for jm = 1:nm
%         for jms = 1:size(ar.model(jm).ms_link,1)
%             tmpres1 = ar.model(jm).condition(ar.model(jm).ms_link(jms,1)).xExpSimu(ar.model(jm).ms_link(jms,4),:);
%             tmpres2 = ar.model(jm).condition(ar.model(jm).ms_link(jms,2)).xExpSimu(ar.model(jm).ms_link(jms,5),:);
%             ar.ms_violation = [ar.ms_violation (log10(tmpres1) - log10(tmpres2)).^2];
%             
%             if(ar.ms_strength>0)
%                 tmpres = sqrt(ar.ms_strength) * (log10(tmpres1) - log10(tmpres2));
%                 ar.res(resindex:(resindex+length(tmpres(:))-1)) = tmpres;
%                 resindex = resindex+length(tmpres(:));
%                 
%                 if(ar.config.useSensis && sensi)
%                     tmpsres1 = zeros(length(tmpres(:)), np);
%                     tmpsres1(:,ar.model(jm).condition(ar.model(jm).ms_link(jms,1)).pLink) = ...
%                         reshape(ar.model(jm).condition(ar.model(jm).ms_link(jms,1)).sxExpSimu(...
%                         ar.model(jm).ms_link(jms,4),:,:), length(tmpres(:)), ...
%                         sum(ar.model(jm).condition(ar.model(jm).ms_link(jms,1)).pLink));
%                     
%                     tmpsres2 = zeros(length(tmpres(:)), np);
%                     tmpsres2(:,ar.model(jm).condition(ar.model(jm).ms_link(jms,2)).pLink) = ...
%                         reshape(ar.model(jm).condition(ar.model(jm).ms_link(jms,2)).sxExpSimu(...
%                         ar.model(jm).ms_link(jms,5),:,:), length(tmpres(:)), ...
%                         sum(ar.model(jm).condition(ar.model(jm).ms_link(jms,2)).pLink));
%                     
%                     tmpsres = sqrt(ar.ms_strength) * (tmpsres1./(tmpres1'*ones(1,np)) - (tmpsres2./(tmpres2'*ones(1,np)))) / log(10);
%                     
%                     for j=find(ar.qLog10==1)
%                         tmpsres(:,j) = tmpsres(:,j) * 10.^ar.p(j) * log(10);
%                     end
%                     
%                     ar.sres(sresindex:(sresindex+length(tmpres(:))-1),:) = tmpsres;
%                     sresindex = sresindex+length(tmpres(:));
%                 end
%             end
%         end
%     end
% end

% cut off too long arrays
if(isfield(ar.model, 'data') && isfield(ar,'res'))
    if(length(ar.res)>=resindex)
        ar.res(resindex:end) = [];
    end
    if(ar.config.useSensis && sensi && size(ar.sres,1)>=sresindex)
        ar.sres(sresindex:end,:) = [];
    end
end

if(ar.config.fiterrors == 1)
    ar.chi2fit = ar.chi2 + ar.chi2err;
else
    ar.chi2fit = ar.chi2;
end

% set Inf for errors
if(has_error)
    ar.res(:) = Inf;
    ar.chi2 = Inf;
    ar.chi2err = Inf;
    ar.chi2fit = Inf;
end
    
if(~silent && ar.ndata>0)
    if(ar.config.fiterrors == 1)
        fprintf('-2*log(L) = %f, %i data points, %i free parameters', ...
            2*ar.ndata*log(sqrt(2*pi)) + ar.chi2fit, ar.ndata, sum(ar.qFit==1));
    else
        fprintf('global chi^2 = %f, %i data points, %i free parameters', ar.chi2, ar.ndata, sum(ar.qFit==1));
    end
    if(ar.chi2constr ~=0)
        fprintf(', %f violation of %i constraints', ar.chi2constr, ar.nconstr);
    end
    if(ar.chi2prior ~=0)
        fprintf(', %f violation of %i prior assumptions', ar.chi2prior, ar.nprior);
    end
    fprintf('\n');
end

if(has_error)
    rethrow(error_id)
end

if(isfield(ar.model, 'data') && isfield(ar,'res'))
    if(sum(isnan(ar.res))>0)
        error('NaN in residuals: %i', sum(isnan(ar.res)));
    end
    if(sensi && isfield(ar,'sres') && sum(sum(isnan(ar.sres(:,ar.qFit==1))))>0)
        for jm = 1:nm
            if(isfield(ar.model(jm), 'data'))
                nd = length(ar.model(jm).data);
                for jd = 1:nd
                    if(ar.model(jm).data(jd).has_yExp)
                        ar.model(jm).data(jd).syExpSimu (:) = 0;
                        ar.model(jm).data(jd).systdExpSimu (:) = 0;
                        ar.model(jm).data(jd).sres(:) = 0;
                        ar.model(jm).data(jd).sreserr(:) = 0;
                    end
                end
            end
        end
        error('NaN in derivative of residuals: %i', sum(sum(isnan(ar.sres(:,ar.qFit==1)))));
    end
end
