% Plot models sensitivities of residuals
%
% arPlotSY

function arPlotSRES

global ar

if(isempty(ar))
    error('please initialize by arInit')
end
if(~isfield(ar.config,'useFitErrorMatrix'))
    ar.config.useFitErrorMatrix = false;
end

% arChi2(true);

fcount = 1;
for jm = 1:length(ar.model)
    nd = length(ar.model(jm).data);
    for jd = 1:nd
        myRaiseFigure(jm, ['SRES: ' ar.model(jm).data(jd).name ' - ' ar.model(jm).data(jd).checkstr], fcount, jd);
        
        % rows and cols
        ny = size(ar.model(jm).data(jd).y, 2);
        [nrows, ncols] = arNtoColsAndRows(ny);
        
        np = length(ar.model(jm).data(jd).p);
        for jy = 1:ny
            g = subplot(nrows,ncols,jy);
            arSubplotStyle(g);
            
            legendhandle = zeros(1,np);
            
            for jp = 1:np
                linestyle = arLineMarkersAndColors(jp, np, [], 'none');
                ltmp = plot(g, ar.model(jm).data(jd).tExp, ar.model(jm).data(jd).sres(:,jy,jp), linestyle{:}, 'Marker', 'o');
                legendhandle(jp) = ltmp;
                hold(g, 'on');
                if(isfield(ar.model(jm).data(jd), 'sresFD'))
                    plot(g, ar.model(jm).data(jd).tExp, ar.model(jm).data(jd).sresFD(:,jy,jp), linestyle{:}, 'Marker', '*');
                end
            end
            hold(g, 'off');
            
            arSpacedAxisLimits(g);
            title(g, arNameTrafo(ar.model(jm).data(jd).y{jy}));
            if(jy == 1)
                legend(g, legendhandle, arNameTrafo(ar.model(jm).data(jd).p));
            end
            
            if(jy == (nrows-1)*ncols + 1)
                xlabel(g, sprintf('%s [%s]', ar.model(jm).data(jd).tUnits{3}, ar.model(jm).data(jd).tUnits{2}));
                ylabel(g, 'sensitivity');
            end
        end      
        fcount = fcount + 1;
    end
end

if( (ar.config.useFitErrorMatrix==0 && ar.config.fiterrors == 1) || ...
        (ar.config.useFitErrorMatrix==1 && sum(sum(ar.config.fiterrors_matrix==1))>0) )
    arPlotSRESERR
end


function h = myRaiseFigure(m, figname, jk, jd)
global ar
openfigs = get(0,'Children');

figcolor = [1 1 1];
figdist = 0.02;

if(isfield(ar.model(m).data(jd), 'fighandel_sres') && ~isempty(ar.model(m).data(jd).fighandel_sres) && ...
        ar.model(m).data(jd).fighandel_sres ~= 0 && sum(ar.model(m).data(jd).fighandel_sres==openfigs)>0 && ...
        strcmp(get(ar.model(m).data(jd).fighandel_sres, 'Name'), figname))
    h = ar.model(m).data(jd).fighandel_sres;
    figure(h);
else
    h = figure('Name', figname, 'NumberTitle','off', ...
        'Units', 'normalized', 'Position', ...
        [0.05+((jk-1)*figdist) 0.45-((jk-1)*figdist) 0.3 0.45]);
    set(h,'Color', figcolor);
    ar.model(m).data(jd).fighandel_sres = h;
end


