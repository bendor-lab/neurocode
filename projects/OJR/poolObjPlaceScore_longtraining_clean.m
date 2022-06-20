%% pool objScore across sessions 
%longer training pool HLR 05/2022
%TO DO add export to csv of pooled results/stats for things importing to py
%TO DO if using matlab to graph change colors for finalization

clearvars;
dirData = 'N:\OJRproject\';
%dirData = 'Z:\ObjRipple\recordings\';
dirSave = 'N:\OJRproject\analysis_repo\behavior_longtraining';

animals = {'OJR42','OJR43', 'OJR44', 'OJR45','OJR46','OJR47', 'OJR48','OJR51','OJR52'}; 


days = {{'day11','day12'};{'day7','day10'};{'day11','day16'};{'day8','day9','day12'};...
        {'day8','day15','day16'};{'day10','day11','day15'};{'day10','day11','day13'};{'day5','day8'};{'day13'}};


condition = {[1 1]; [1 1]; [4 5]; [4 5 1]; [4 5 1]; [1 5 4]; [1 5 4]; [4 5]; [5]};


% 1=4h sham; 2=4h cl; 3=4h ol; 4=4h cl+PFC inh; 5=4h cl+PFC delay;
% 6=1h sham; 7=1h PFC inh; 8=1h PFC delay

%% pool
DIcond = cell(8,1);OPcond = cell(8,1);trainT = cell(8,1);testT = cell(8,1);

for a = 1:length(animals)
    for d = 1:length(days{a})
        cd([dirData animals{a} '\' days{a}{d}]);
        load('objScore.mat');
        
        for c = 1:8
            if condition{a}(d) == c
               DIcond{c} = cat(1,DIcond{c},objScore.discrimination_index);
               %OPcond{c} = cat(1,OPcond{c},objScore.object_preference);               
               trainT{c} = cat(1,trainT{c},objScore.object_training_time(1)+objScore.object_training_time(2));
               testT{c} = cat(1,testT{c},objScore.object_test_time(1)+objScore.object_test_time(2));
            end
        end
        clear objScore;
        
    end
end
        
%% %%%%%%%%%%%%%%%%% plot       


%% Figure  4h PFC exp
box4hPFC = nan(20,3);
box4hPFC(1:numel(DIcond{1}),1) = DIcond{1};
box4hPFC(1:numel(DIcond{4}),2) = DIcond{4};
box4hPFC(1:numel(DIcond{5}),3) = DIcond{5};

figure; 
boxplot(box4hPFC,'Notch','on','Labels',{'control','stim + inh','stim + delayed'});hold on;
lines = findobj(gcf, 'type', 'line', 'Tag', 'Median');
ylabel('discrimination index');title('PFC: 3x Training + 4h delayed recall');
set(lines, 'Color', 'b','LineWidth',2);
plot(xlim,[0 0],'--k');hold on;

x=ones(numel(DIcond{1})).*(1+(rand(numel(DIcond{1}))-0.5)/5);
x1=ones(numel(DIcond{4})).*(1+(rand(numel(DIcond{4}))-0.5)/10);
x2=ones(numel(DIcond{5})).*(1+(rand(numel(DIcond{5}))-0.5)/15);
f1=scatter(x(:,1),DIcond{1},'k','filled');f1.MarkerFaceAlpha = 0.4;hold on 
f2=scatter(x1(:,2).*2,DIcond{4},'k','filled');f2.MarkerFaceAlpha = f1.MarkerFaceAlpha;hold on
f3=scatter(x2(:,3).*3,DIcond{5},'k','filled');f3.MarkerFaceAlpha = f1.MarkerFaceAlpha;hold on

p1=signrank(DIcond{1});
p2=signrank(DIcond{4});
p3=signrank(DIcond{5});
p4=ranksum(DIcond{4},DIcond{1});
p5=ranksum(DIcond{5},DIcond{1});
p6=ranksum(DIcond{4},DIcond{5});

yt = get(gca,'YTick');  xt = get(gca,'XTick');hold on
axis([xlim floor(min(yt)*1.2) ceil(max(yt)*1.4)])
plot(xt([1 2]), [1 1]*max(yt)*1.15, '-k',  mean(xt([1 2])), max(yt)*1.2);hold on;
text(mean([xt(1),xt(2)]),max(yt)*1.22,['p=' num2str(p4,2)],'FontSize',12);hold on;
plot(xt([1 3]), [1 1]*max(yt)*1.25, '-k',  mean(xt([1 3])), max(yt)*1.3);hold on;
text(mean([xt(2),xt(3)]),max(yt)*1.32,['p=' num2str(p5,2)],'FontSize',12);hold on;
plot(xt([2 3]), [1 1]*max(yt)*1.15, '-k',  mean(xt([2 3])), max(yt)*1.2);hold on;
text(mean([xt(2),xt(3)]),max(yt)*1.22,['p=' num2str(p6,2)],'FontSize',12);hold on;

text(xt(1),max(yt)*1.05,['p=' num2str(p1,2)],'FontSize',12);hold on;
text(xt(2),max(yt)*1.05,['p=' num2str(p2,2)],'FontSize',12);hold on;
text(xt(3),max(yt)*1.05,['p=' num2str(p3,2)],'FontSize',12);hold on;

saveas(gcf,'N:\OJRproject\analysis_repo\behavior_longtraining');
saveas(gcf,'N:\OJRproject\analysis_repo\behavior_longtraining\longtraining.png');



