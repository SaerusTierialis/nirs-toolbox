classdef Probe1020 < nirs.core.Probe
    %% Probe1020.  This is a class derived from the core Probe class which adds
    % methods for registration, display, and co-registration based on the 10-20
    % landmarking
    
    properties
        optodes_registered;   % Registered version of optodes 
        braindepth;  % depth of brain for modeling
        opticalproperties;  % optical properties for modeling
        AP_distance;
        LR_distance;
        IS_distance;
        labels;
        pts1020;
        defaultdrawfcn;
        
    end
    properties( Dependent = true )
      
        headcircum;  % circumference of head  % make dependent
        AP_arclength; % Anterior-Posterior arc length
        LR_arclength; % Left-right arclength
    end
    
    methods
        
        function obj = Probe1020(probe)
            
            fid=fopen(which('ext1020.sfp'),'r');
            marker=textscan(fid,'%s\t%d\t%d\t%d');
            fclose(fid);
            obj.pts1020=double([marker{2} marker{3} marker{4}]);
            obj.labels=marker{1};
            
            % Find the default arc lengths
            pt(1,:)=obj.pts1020(find(ismember(obj.labels,'spmlpa')),:);
            pt(2,:)=obj.pts1020(find(ismember(obj.labels,'spmrpa')),:);
            pt(3,:)=obj.pts1020(find(ismember(obj.labels,'Cz')),:);
            pt(4,:)=obj.pts1020(find(ismember(obj.labels,'spmnas')),:);
            pt(5,:)=obj.pts1020(find(ismember(obj.labels,'Iz')),:);
            
            obj.AP_distance=norm(pt(4,:)-pt(5,:));
            obj.LR_distance=norm(pt(1,:)-pt(2,:));
            obj.IS_distance=norm(pt(3,:)-.5*(pt(1,:)-pt(2,:)));
            
            
            obj.braindepth = 10;  % Fix and cite
            
            if(nargin>0)
                obj=obj.registerprobe(probe);
                lambda=unique(obj.optodes.type);
            else
                lambda=[808];
            end
            
            obj.opticalproperties = nirs.media.tissues.brain(0.7, 50,lambda);
            
            obj.defaultdrawfcn='draw1020';
        end
        
        function l=draw(obj,varargin)
            if(strcmp(obj.defaultdrawfcn,'draw1020'));
                l=draw1020(obj,varargin{:});
            elseif(strcmp(obj.defaultdrawfcn,'draw3d'));
                l=draw3d(obj,varargin{:});
            elseif(strcmp(obj.defaultdrawfcn,'draw1020interp'));
                l=draw1020interp(obj,varargin{:});
            else
                l=draw@nirs.core.Probe(obj,varargin{:});
            end
                
        end
        
        function obj=swap_reg(obj)
            op=obj.optodes;
            obj.optodes=obj.optodes_registered;
            obj.optodes_registered=op;
        end
        function mesh = getmesh(obj);
            % create the spherical mesh
            mesh(1) = nirs.util.spheremesh;
            mesh(2) = nirs.util.spheremesh;
            mesh(3) = nirs.util.spheremesh;
            
            pt(1,:)=obj.pts1020(find(ismember(obj.labels,'spmnas')),:);
            pt(2,:)=obj.pts1020(find(ismember(obj.labels,'Iz')),:);
            com=.5*sum(pt,1);
            
            fract=.2;
            mesh(1).nodes(:,1)=mesh(1).nodes(:,1)*obj.LR_distance/2+com(1);
            mesh(1).nodes(:,2)=mesh(1).nodes(:,2)*obj.AP_distance/2+com(2);
            mesh(1).nodes(:,3)=mesh(1).nodes(:,3)*obj.IS_distance+com(3);
            
            mesh(2).nodes(:,1)=mesh(2).nodes(:,1)*(obj.LR_distance/2-obj.braindepth*fract)+com(1);
            mesh(2).nodes(:,2)=mesh(2).nodes(:,2)*(obj.AP_distance/2-obj.braindepth*fract)+com(2);
            mesh(2).nodes(:,3)=mesh(2).nodes(:,3)*(obj.IS_distance-obj.braindepth*fract)+com(3);
            
            mesh(3).nodes(:,1)=mesh(3).nodes(:,1)*(obj.LR_distance/2-obj.braindepth)+com(1);
            mesh(3).nodes(:,2)=mesh(3).nodes(:,2)*(obj.AP_distance/2-obj.braindepth)+com(2);
            mesh(3).nodes(:,3)=mesh(3).nodes(:,3)*(obj.IS_distance-obj.braindepth)+com(3);
            
            
            [TR, TT] = icp(mesh(1).nodes',obj.pts1020');
            mesh(1).nodes=(TR'*mesh(1).nodes'-TT*ones(1,size(mesh(1).nodes,1)))';
            mesh(2).nodes=(TR'*mesh(2).nodes'-TT*ones(1,size(mesh(2).nodes,1)))';
            mesh(3).nodes=(TR'*mesh(3).nodes'-TT*ones(1,size(mesh(3).nodes,1)))';
            
            fidtbl=table(obj.labels,obj.pts1020(:,1),obj.pts1020(:,2),obj.pts1020(:,3),...
                repmat({'10-20'},length(obj.labels),1),...
                repmat({'mm'},length(obj.labels),1),...
                repmat(true,length(obj.labels),1),...
                'VariableNames',{'Name','X','Y','Z','Units','Type','Draw'});
            mesh(1).fiducials=fidtbl;
            mesh(1).transparency=.2;
            mesh(2).transparency=.1;
             
        end
        
        function [x,y]=convert2d(obj,pts)
            
            %Clarke far-side general prospective azumuthal projection
            r = -2.4;
            R=sqrt(sum(pts.^2,2));
            x=r*R.*(pts(:,1)./abs(pts(:,3)-r*R));
            y=r*R.*(pts(:,2)./abs(pts(:,3)-r*R));
            
        end
        function h=draw3d(obj,colors, lineStyles, axis_handle)
             link = unique( [obj.link.source obj.link.detector], 'rows' );
            
            
            n = size(link, 1);
            
            if nargin < 2 || isempty(colors)
                colors = repmat([0.3 0.5 1], [n 1]);
            elseif size(colors,1) == 1
                colors = repmat(colors, [n 1]);
            end
            
            if nargin < 3 || isempty(lineStyles)
                lineStyles = repmat({'LineStyle', '-', 'LineWidth', 6}, [n 1]);
            elseif size(lineStyles, 1) == 1
                lineStyles = repmat({'LineStyle', '-', 'LineWidth', 6}, [n 1]);
            end
            
            if nargin < 4
                axis_handle = axes();
            end
            
            % Points from the probe
            Pos(:,1)=obj.optodes_registered.X;
            Pos(:,2)=obj.optodes_registered.Y;
            Pos(:,3)=obj.optodes_registered.Z;
           
            hold on;
            lstS=find(ismember(obj.optodes.Type,'Source'));
            scatter3(Pos(lstS,1),Pos(lstS,2),Pos(lstS,3),'filled','MarkerFaceColor','r')
            lstD=find(ismember(obj.optodes.Type,'Detector'));
            scatter3(Pos(lstD,1),Pos(lstD,2),Pos(lstD,3),'filled','MarkerFaceColor','b')
            
            for i=1:size(link,1)
                s=link(i,1);
                d=link(i,2);
                h(i)=line(Pos([lstS(s) lstD(d)],1),Pos([lstS(s) lstD(d)],2),Pos([lstS(s) lstD(d)],3),'Color', colors(i, :), lineStyles{i, :});
                set(h(i),'UserData',[s d]);
            end
            
            axis equal;
        end
        
        function h=draw1020interp(obj,colors, lineStyles, axis_handle)
            link = unique( [obj.link.source obj.link.detector], 'rows' );
            n = size(link, 1);
            if nargin < 2 || isempty(colors)
                colors = repmat([0.3 0.5 1], [n 1]);
            elseif size(colors,1) == 1
                colors = repmat(colors, [n 1]);
            end
            
            if nargin < 3 || isempty(lineStyles)
                lineStyles = repmat({'LineStyle', '-', 'LineWidth', 6}, [n 1]);
            elseif size(lineStyles, 1) == 1
                lineStyles = repmat({'LineStyle', '-', 'LineWidth', 6}, [n 1]);
            end
            
            if nargin < 4
                axis_handle = axes();
            end
            
            h=draw1020(obj,[],[],axis_handle);
           delete(h);
            lstS=find(ismember(obj.optodes.Type,'Source'));
            lstD=find(ismember(obj.optodes.Type,'Detector'));
            
            Pos(:,1)=obj.optodes_registered.X;
            Pos(:,2)=obj.optodes_registered.Y;
            Pos(:,3)=obj.optodes_registered.Z;
            [x,y]=obj.convert2d(Pos);
            for i=1:size(link,1)
                s=link(i,1);
                d=link(i,2);
                xylink(i,1)=mean(x([lstS(s) lstD(d)]));
                xylink(i,2)=mean(y([lstS(s) lstD(d)]));
                
            end
            
            xlim=get(axis_handle,'XLim');
            ylim=get(axis_handle,'YLim');
            [x,y]=meshgrid(xlim(1):xlim(2),ylim(1):ylim(2));
            
            F = scatteredInterpolant(xylink(:,1),xylink(:,2),colors(:,1),'nearest','none');
            cm(:,:,1)=reshape(F(x(:),y(:)),size(x));
            F.Values=colors(:,2);
            cm(:,:,2)=reshape(F(x(:),y(:)),size(x));
            F.Values=colors(:,3);
            cm(:,:,3)=reshape(F(x(:),y(:)),size(x));
            
            
            k=dsearchn(colors,reshape(cm,[],3));
            k=reshape(k,size(cm,1),size(cm,2));
            lst=find(ismember(k,find(strcmp(lineStyles(:,2),'--'))));
            
            mask=ones(size(cm,1),size(cm,2));
            mask(lst)=NaN;
            cm(:,:,1)=mask.*cm(:,:,1);
            cm(:,:,2)=mask.*cm(:,:,2);
            cm(:,:,3)=mask.*cm(:,:,3);
            
            i=imagesc(x(:),y(:),cm);
            h=draw1020(obj,[],[],axis_handle);
            set(h,'LineWidth',.1,'color',[.3 .3 .3]);
            set(i,'alphaData',~isnan(cm(:,:,1)));
        end
        
        function h=draw1020(obj,colors, lineStyles, axis_handle)
            % Code to draw the probe in 10-20 space
            
            link = unique( [obj.link.source obj.link.detector], 'rows' );
            
            
            n = size(link, 1);
            
            if nargin < 2 || isempty(colors)
                colors = repmat([0.3 0.5 1], [n 1]);
            elseif size(colors,1) == 1
                colors = repmat(colors, [n 1]);
            end
            
            if nargin < 3 || isempty(lineStyles)
                lineStyles = repmat({'LineStyle', '-', 'LineWidth', 6}, [n 1]);
            elseif size(lineStyles, 1) == 1
                lineStyles = repmat({'LineStyle', '-', 'LineWidth', 6}, [n 1]);
            end
            
            if nargin < 4
                axis_handle = axes();
            end
            
            hold on;
            [x,y]=obj.convert2d(obj.pts1020);
            scatter(x,y,'filled','MarkerFaceColor',[.8 .8 .8]);
            
            % Todo-  draw the probe too
            
            % Points from the probe
            Pos(:,1)=obj.optodes_registered.X;
            Pos(:,2)=obj.optodes_registered.Y;
            Pos(:,3)=obj.optodes_registered.Z;
            [x,y]=obj.convert2d(Pos);    
            
            lstS=find(ismember(obj.optodes.Type,'Source'));
            scatter(x(lstS),y(lstS),'filled','MarkerFaceColor','r')
            lstD=find(ismember(obj.optodes.Type,'Detector'));
            scatter(x(lstD),y(lstD),'filled','MarkerFaceColor','b')
            
            for i=1:size(link,1)
                s=link(i,1);
                d=link(i,2);
                h(i)=line(x([lstS(s) lstD(d)]),y([lstS(s) lstD(d)]),'Color', colors(i, :), lineStyles{i, :});
                set(h(i),'UserData',[s d]);
            end
            %%
            
            
            axis tight;
            axis equal;
            axis off;
            
            headradius=obj.headcircum/(2*pi);
            
            % add a circle for the head
            theta = linspace(0,2*pi);
            plot(headradius*cos(theta),headradius*sin(theta),'k');
            line([-10 0],[-headradius -headradius-10],'color','k');
            line([10 0],[-headradius -headradius-10],'color','k');
            scatter([-15 15],[-headradius -headradius],'filled','k','sizedata',120);
            
            set(gca,'YDir','reverse');
            set(gcf,'color','w');
        end
        
        function headcircum = get.headcircum(obj)
            a=obj.LR_distance/2;
            b=obj.AP_distance/2;
            headcircum=.9*pi*(3*(a+b)-sqrt((3*a+b)*(a+3*b)));
            
        end
        
        function LR_arclength = get.LR_arclength(obj)
            a=obj.LR_distance/2;
            b=obj.IS_distance;
            LR_arclength=pi*(3*(a+b)-sqrt((3*a+b)*(a+3*b)))/2;
            
        end
        
        function AP_arclength = get.AP_arclength(obj)
            a=obj.AP_distance/2;
            b=obj.IS_distance;
            AP_arclength=pi*(3*(a+b)-sqrt((3*a+b)*(a+3*b)))/2;
            
        end
        
        
        
        
        %draw1020image;  % Code to draw an image in 10-20space
        % makeimage;  % code to do simple image reconstruction in 10-20 space
        %registerprobe;
        % depth map
        % define ROIs
        % coregister
        % register probe
        
        
        
    end
    
end